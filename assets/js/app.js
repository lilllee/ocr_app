// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).
import "../css/app.css"

// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// OCR 앱 기능 초기화
document.addEventListener('DOMContentLoaded', function() {
  const form = document.getElementById('upload-form');
  const fileInput = document.getElementById('image-upload');
  const preview = document.getElementById('image-preview');
  const previewContainer = document.getElementById('preview-container');
  const ocrResults = document.getElementById('ocr-results');
  const copyButton = document.getElementById('copy-button');
  const saveButton = document.getElementById('save-button');
  const loadingIndicator = document.getElementById('loading-indicator');
  
  if (fileInput) {
    fileInput.addEventListener('change', function(e) {
      const file = this.files[0];
      if (file) {
        // 파일 유형 검사
        const fileType = file.type;
        if (!fileType.match('image.*')) {
          alert('이미지 파일만 업로드 가능합니다.');
          this.value = '';
          return;
        }
        
        // 이미지 미리보기
        const reader = new FileReader();
        reader.onload = function(e) {
          preview.src = e.target.result;
          previewContainer.classList.remove('hidden');
        };
        reader.readAsDataURL(file);
      }
    });
  }
  
  if (form) {
    form.addEventListener('submit', function(e) {
      e.preventDefault();
      
      const file = fileInput.files[0];
      if (!file) {
        alert('이미지 파일을 선택해주세요.');
        return;
      }
      
      // 로딩 표시
      if (loadingIndicator) {
        loadingIndicator.classList.remove('hidden');
      }
      
      // 폼 데이터 생성
      const formData = new FormData(form);
      
      // OCR 요청
      fetch('/api/ocr/upload', {
        method: 'POST',
        body: formData
      })
      .then(response => response.json())
      .then(data => {
        // 로딩 숨기기
        if (loadingIndicator) {
          loadingIndicator.classList.add('hidden');
        }
        
        if (data.success && ocrResults) {
          // 결과를 정확히 원본 형식대로 표시
          ocrResults.textContent = data.text;
          
          // 결과 상자 표시
          const resultsBox = document.querySelector('.results-box');
          if (resultsBox) {
            resultsBox.style.display = 'block';
          }
          
          // 복사 및 저장 버튼 활성화
          if (copyButton) copyButton.style.display = 'inline-block';
          if (saveButton) saveButton.style.display = 'inline-block';
        } else {
          if (ocrResults) {
            ocrResults.textContent = '오류가 발생했습니다: ' + (data.error || '알 수 없는 오류');
          }
        }
      })
      .catch(error => {
        console.error('OCR 요청 중 오류 발생:', error);
        if (loadingIndicator) {
          loadingIndicator.classList.add('hidden');
        }
        if (ocrResults) {
          ocrResults.textContent = '오류가 발생했습니다. 다시 시도해주세요.';
        }
      });
    });
  }
  
  // 복사 버튼 기능
  if (copyButton) {
    copyButton.addEventListener('click', function() {
      if (ocrResults && ocrResults.textContent) {
        navigator.clipboard.writeText(ocrResults.textContent)
          .then(() => {
            alert('텍스트가 클립보드에 복사되었습니다.');
          })
          .catch(err => {
            console.error('클립보드 복사 중 오류 발생:', err);
            alert('클립보드 복사에 실패했습니다.');
          });
      }
    });
  }
  
  // 저장 버튼 기능
  if (saveButton) {
    saveButton.addEventListener('click', function() {
      if (ocrResults && ocrResults.textContent) {
        const text = ocrResults.textContent;
        const blob = new Blob([text], { type: 'text/plain;charset=utf-8' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'ocr_result.txt';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      }
    });
  }
});

// 언어 코드를 표시 이름으로 변환
function getLanguageName(code) {
  const languages = {
    'eng': '영어',
    'kor': '한국어',
    'jpn': '일본어',
    'chn': '중국어 (간체)',
    'auto': '자동 감지'
  };
  
  return languages[code] || code;
}

// PSM 코드를 설명으로 변환
function getPsmDescription(psm) {
  const psmDescriptions = {
    0: 'OSD만 (방향 및 스크립트 감지)',
    1: '자동 페이지 분할 + OSD',
    2: '자동 페이지 분할 (OSD 없음)',
    3: '완전 자동 페이지 분할 (기본값)',
    4: '단일 열의 가변 크기 텍스트',
    5: '수직으로 정렬된 단일 블록 텍스트',
    6: '단일 블록 텍스트',
    7: '한 줄의 텍스트',
    8: '한 단어',
    9: '원 내부의 한 단어',
    10: '한 문자',
    11: '드문드문 텍스트',
    12: '드문드문 텍스트 + OSD',
    13: '원시 라인'
  };
  
  return psmDescriptions[psm] || `PSM ${psm}`;
}

