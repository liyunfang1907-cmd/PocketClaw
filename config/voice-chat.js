// PocketClaw 语音对话插件 v2.0 (TTS + STT)
// 通过 Web Speech API 实现，零成本、纯前端
// 兼容性：TTS 全平台可用，STT 仅限支持的浏览器 + 安全上下文
(function() {
  'use strict';

  // 检测 API 支持情况（分别检测，互不影响）
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  const synth = window.speechSynthesis;
  const hasSTT = !!SpeechRecognition;
  const hasTTS = !!synth;
  const isSecure = location.protocol === 'https:' ||
                   location.hostname === 'localhost' ||
                   location.hostname === '127.0.0.1';

  // 如果 TTS 和 STT 都不支持，直接退出
  if (!hasSTT && !hasTTS) return;

  let recognition = null;
  let isListening = false;
  let ttsEnabled = true;
  let lastReadIndex = 0;

  // ── 延迟初始化（等待 SPA 渲染完成）──
  function init() {
    if (document.getElementById('pc-voice-container')) return;

    const container = document.createElement('div');
    container.id = 'pc-voice-container';

    // 根据可用功能决定显示哪些按钮
    // TTS 按钮：几乎所有浏览器都支持 speechSynthesis，始终显示
    // 麦克风按钮：仅在支持 SpeechRecognition 时显示
    const ttsBtnHtml = hasTTS
      ? '<button id="pc-tts-btn" class="pc-voice-btn" title="语音朗读开关">🔊</button>'
      : '';
    const micBtnHtml = hasSTT
      ? '<button id="pc-mic-btn" class="pc-voice-btn" title="点击说话">🎤</button>'
      : '';

    container.innerHTML = `
      <style>
        #pc-voice-container {
          position: fixed;
          bottom: 80px;
          right: 16px;
          z-index: 99999;
          display: flex;
          flex-direction: column;
          gap: 8px;
          align-items: flex-end;
        }
        .pc-voice-btn {
          width: 52px;
          height: 52px;
          border-radius: 50%;
          border: none;
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 24px;
          box-shadow: 0 2px 12px rgba(0,0,0,0.3);
          transition: transform 0.15s, box-shadow 0.15s;
          -webkit-tap-highlight-color: transparent;
          touch-action: manipulation;
        }
        .pc-voice-btn:active { transform: scale(0.92); }
        #pc-mic-btn {
          background: #f97316;
          color: white;
        }
        #pc-mic-btn.listening {
          background: #ef4444;
          animation: pc-pulse 1s infinite;
        }
        #pc-mic-btn.unavailable {
          background: #6b7280;
          opacity: 0.6;
        }
        #pc-tts-btn {
          width: 44px;
          height: 44px;
          font-size: 20px;
          background: rgba(100,100,100,0.8);
          color: white;
          backdrop-filter: blur(8px);
        }
        #pc-tts-btn.off { opacity: 0.4; }
        @keyframes pc-pulse {
          0%, 100% { box-shadow: 0 0 0 0 rgba(239,68,68,0.5); }
          50% { box-shadow: 0 0 0 12px rgba(239,68,68,0); }
        }
        #pc-voice-status {
          background: rgba(0,0,0,0.75);
          color: white;
          padding: 6px 14px;
          border-radius: 16px;
          font-size: 13px;
          max-width: 220px;
          text-align: center;
          backdrop-filter: blur(8px);
          opacity: 0;
          transition: opacity 0.2s;
          pointer-events: none;
        }
        #pc-voice-status.show { opacity: 1; }
        /* 手机适配：按钮更大、位置更明显 */
        @media (max-width: 768px) {
          #pc-voice-container {
            bottom: 90px;
            right: 12px;
          }
          .pc-voice-btn {
            width: 56px;
            height: 56px;
            font-size: 26px;
          }
          #pc-tts-btn {
            width: 48px;
            height: 48px;
            font-size: 22px;
          }
        }
      </style>
      <div id="pc-voice-status"></div>
      ${ttsBtnHtml}
      ${micBtnHtml}
    `;
    document.body.appendChild(container);

    const micBtn = hasSTT ? document.getElementById('pc-mic-btn') : null;
    const ttsBtn = hasTTS ? document.getElementById('pc-tts-btn') : null;
    const statusEl = document.getElementById('pc-voice-status');

    let statusTimer = null;
    function showStatus(msg, duration) {
      statusEl.textContent = msg;
      statusEl.classList.add('show');
      clearTimeout(statusTimer);
      if (duration) {
        statusTimer = setTimeout(() => statusEl.classList.remove('show'), duration);
      }
    }

    // ── 麦克风按钮事件 ──
    if (micBtn) {
      if (!isSecure) {
        // HTTP + 非 localhost：语音识别会被浏览器拦截
        micBtn.classList.add('unavailable');
        micBtn.addEventListener('click', () => {
          showStatus('⚠️ 语音输入需要 HTTPS 连接', 3000);
        });
      } else {
        micBtn.addEventListener('click', () => {
          if (isListening) {
            stopListening();
          } else {
            startListening(micBtn, showStatus);
          }
        });
      }
    }

    // ── TTS 按钮事件 ──
    if (ttsBtn) {
      ttsBtn.addEventListener('click', () => {
        ttsEnabled = !ttsEnabled;
        ttsBtn.classList.toggle('off', !ttsEnabled);
        ttsBtn.textContent = ttsEnabled ? '🔊' : '🔇';
        if (!ttsEnabled) synth.cancel();
        showStatus(ttsEnabled ? '语音朗读已开启' : '语音朗读已关闭', 1500);
        const msgs = document.querySelectorAll(
          '[data-role="assistant"], .assistant-message, .message-assistant, [class*="assistant"], [class*="bot-message"]'
        );
        lastReadIndex = msgs.length;
      });
    }

    // 启动消息监听（TTS 自动朗读新消息）
    if (hasTTS) {
      observeMessages();
      synth.getVoices();
      speechSynthesis.addEventListener('voiceschanged', () => synth.getVoices());
    }

    console.log('[PocketClaw] 语音插件已加载' +
      (hasSTT && isSecure ? ' | STT ✓' : hasSTT ? ' | STT (需HTTPS)' : ' | STT ✗') +
      (hasTTS ? ' | TTS ✓' : ' | TTS ✗'));
  }

  // ── STT (语音转文字) ──
  function startListening(micBtn, showStatus) {
    if (isListening) return;
    if (synth) synth.cancel();
    recognition = new SpeechRecognition();
    recognition.lang = 'zh-CN';
    recognition.interimResults = true;
    recognition.continuous = false;
    recognition.maxAlternatives = 1;

    recognition.onstart = () => {
      isListening = true;
      micBtn.classList.add('listening');
      micBtn.textContent = '⏹';
      showStatus('正在听...');
    };

    recognition.onresult = (event) => {
      let transcript = '';
      for (let i = 0; i < event.results.length; i++) {
        transcript += event.results[i][0].transcript;
      }
      if (event.results[event.results.length - 1].isFinal) {
        showStatus('识别完成', 1500);
        if (transcript.trim()) {
          injectText(transcript.trim(), showStatus);
        }
      } else {
        showStatus(transcript.slice(-20) || '...', 0);
      }
    };

    recognition.onerror = (event) => {
      if (event.error === 'no-speech') {
        showStatus('未检测到语音', 2000);
      } else if (event.error === 'not-allowed') {
        showStatus('请允许麦克风权限', 3000);
      } else {
        showStatus('识别出错: ' + event.error, 2000);
      }
    };

    recognition.onend = () => {
      isListening = false;
      micBtn.classList.remove('listening');
      micBtn.textContent = '🎤';
    };

    try {
      recognition.start();
    } catch (e) {
      showStatus('无法启动语音识别', 2000);
    }
  }

  function stopListening() {
    if (recognition && isListening) {
      recognition.stop();
    }
  }

  // ── 注入文本到聊天输入框 ──
  function injectText(text, showStatus) {
    const textarea = document.querySelector('textarea[placeholder], textarea[data-testid], .chat-input textarea, textarea');
    if (!textarea) {
      showStatus('未找到输入框', 2000);
      return;
    }
    const nativeInputValueSetter = Object.getOwnPropertyDescriptor(
      window.HTMLTextAreaElement.prototype, 'value'
    ).set;
    nativeInputValueSetter.call(textarea, text);
    textarea.dispatchEvent(new Event('input', { bubbles: true }));
    setTimeout(() => {
      const sendBtn = document.querySelector(
        'button[type="submit"], button[aria-label*="send" i], button[aria-label*="发送" i], button[title*="send" i]'
      );
      if (sendBtn && !sendBtn.disabled) {
        sendBtn.click();
      } else {
        textarea.dispatchEvent(new KeyboardEvent('keydown', {
          key: 'Enter', code: 'Enter', keyCode: 13, bubbles: true
        }));
      }
    }, 100);
  }

  // ── TTS (文字转语音) ──
  function speakText(text) {
    if (!ttsEnabled || !synth) return;
    synth.cancel();
    text = text.replace(/```[\s\S]*?```/g, '（代码块已省略）')
               .replace(/`[^`]+`/g, (m) => m.slice(1, -1))
               .replace(/\*\*([^*]+)\*\*/g, '$1')
               .replace(/\*([^*]+)\*/g, '$1')
               .replace(/#{1,6}\s*/g, '')
               .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
               .replace(/!\[.*?\]\(.*?\)/g, '')
               .replace(/[-*+]\s/g, '')
               .replace(/\n{2,}/g, '。')
               .trim();
    if (!text || text.length < 2) return;
    if (text.length > 500) text = text.slice(0, 500) + '...后面内容较长，已省略。';
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = 'zh-CN';
    utterance.rate = 1.1;
    utterance.pitch = 1.0;
    const voices = synth.getVoices();
    const zhVoice = voices.find(v => v.lang.startsWith('zh')) || voices[0];
    if (zhVoice) utterance.voice = zhVoice;
    synth.speak(utterance);
  }

  // ── 监听新消息（TTS 自动朗读）──
  function observeMessages() {
    setInterval(() => {
      if (!ttsEnabled) return;
      const messages = document.querySelectorAll(
        '[data-role="assistant"], .assistant-message, .message-assistant, [class*="assistant"], [class*="bot-message"]'
      );
      if (messages.length > lastReadIndex) {
        const newMsg = messages[messages.length - 1];
        const text = newMsg.textContent || newMsg.innerText;
        if (text && text.trim().length > 1) {
          lastReadIndex = messages.length;
          setTimeout(() => {
            const finalText = newMsg.textContent || newMsg.innerText;
            speakText(finalText);
          }, 500);
        }
      }
    }, 1000);
  }

  // ── 延迟启动：等 SPA 渲染完毕 ──
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => setTimeout(init, 800));
  } else {
    setTimeout(init, 800);
  }
})();
