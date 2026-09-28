#include "taskbar_controls.h"

#include <commctrl.h>
#include <strsafe.h>

#include <string>

#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment( \
    linker,      \
    "\"/manifestdependency:type='Win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*'\"")

namespace {

constexpr int kMinButtonId = 41000;
constexpr int kMaxButtonCount = 4;

std::wstring Utf8ToUtf16(const std::string& utf8) {
  if (utf8.empty()) return std::wstring();
  int size =
      ::MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (size <= 0) return std::wstring();
  std::wstring utf16(size, 0);
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, utf16.data(), size);
  if (!utf16.empty() && utf16.back() == L'\0') utf16.pop_back();
  return utf16;
}

}

TaskbarControls::TaskbarControls(HWND window,
                                 flutter::BinaryMessenger* messenger)
    : window_(window) {
  ::ChangeWindowMessageFilterEx(window_, WM_COMMAND, MSGFLT_ALLOW, nullptr);

  ::CoCreateInstance(CLSID_TaskbarList, nullptr, CLSCTX_INPROC_SERVER,
                     IID_PPV_ARGS(&taskbar_));
  if (taskbar_) {
    taskbar_->HrInit();
  }

  channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger, "yora/taskbar",
          &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });
}

TaskbarControls::~TaskbarControls() {
  if (taskbar_) {
    taskbar_->Release();
    taskbar_ = nullptr;
  }
}

void TaskbarControls::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name().compare("setThumbnailToolbar") != 0) {
    result->NotImplemented();
    return;
  }
  if (!taskbar_ || !::IsWindowVisible(window_)) {
    result->Error("-1", "Window not ready");
    return;
  }

  const auto* buttons =
      std::get_if<flutter::EncodableList>(call.arguments());
  if (!buttons) {
    result->Error("-1", "Bad arguments");
    return;
  }

  auto image_list = ::ImageList_Create(
      ::GetSystemMetrics(SM_CXSMICON), ::GetSystemMetrics(SM_CXSMICON),
      ILC_MASK | ILC_COLOR32, 0, 0);

  THUMBBUTTON thumb_buttons[kMaxButtonCount];
  for (int i = 0; i < kMaxButtonCount; i++) {
    thumb_buttons[i].iId = kMinButtonId + i;
    if (i < static_cast<int>(buttons->size())) {
      const auto& data = std::get<flutter::EncodableMap>((*buttons)[i]);
      auto icon_path =
          std::get<std::string>(data.at(flutter::EncodableValue("icon")));
      auto tooltip =
          std::get<std::string>(data.at(flutter::EncodableValue("tooltip")));
      auto enabled =
          std::get<bool>(data.at(flutter::EncodableValue("enabled")));

      auto hicon = (HICON)::LoadImage(
          nullptr, Utf8ToUtf16(icon_path).c_str(), IMAGE_ICON,
          ::GetSystemMetrics(SM_CXSMICON), ::GetSystemMetrics(SM_CXSMICON),
          LR_LOADFROMFILE | LR_LOADTRANSPARENT);
      ::ImageList_AddIcon(image_list, hicon);
      if (hicon) ::DestroyIcon(hicon);

      thumb_buttons[i].dwMask = THB_BITMAP | THB_TOOLTIP | THB_FLAGS;
      thumb_buttons[i].dwFlags = enabled ? THBF_ENABLED : THBF_DISABLED;
      thumb_buttons[i].iBitmap = i;
      ::StringCchCopyW(thumb_buttons[i].szTip,
                       ARRAYSIZE(thumb_buttons[i].szTip),
                       Utf8ToUtf16(tooltip).c_str());
    } else {
      thumb_buttons[i].dwMask = THB_FLAGS;
      thumb_buttons[i].dwFlags = THBF_HIDDEN;
    }
  }

  taskbar_->ThumbBarSetImageList(window_, image_list);
  HRESULT hr;
  if (!buttons_added_) {
    hr = taskbar_->ThumbBarAddButtons(window_, kMaxButtonCount, thumb_buttons);
    buttons_added_ = true;
  } else {
    hr = taskbar_->ThumbBarUpdateButtons(window_, kMaxButtonCount,
                                         thumb_buttons);
  }
  ::ImageList_Destroy(image_list);

  if (SUCCEEDED(hr)) {
    result->Success();
  } else {
    result->Error("-1", "ThumbBar call failed");
  }
}

std::optional<LRESULT> TaskbarControls::HandleWindowProc(UINT message,
                                                          WPARAM wparam,
                                                          LPARAM lparam) {
  if (message == WM_COMMAND) {
    int button_id = LOWORD(wparam);
    if (button_id >= kMinButtonId &&
        button_id < kMinButtonId + kMaxButtonCount) {
      int index = button_id - kMinButtonId;
      channel_->InvokeMethod(
          "buttonClick", std::make_unique<flutter::EncodableValue>(index));
      return 0;
    }
  }
  return std::nullopt;
}
