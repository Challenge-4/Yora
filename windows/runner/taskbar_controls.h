#ifndef RUNNER_TASKBAR_CONTROLS_H_
#define RUNNER_TASKBAR_CONTROLS_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <shobjidl.h>
#include <windows.h>

#include <memory>
#include <optional>

class TaskbarControls {
 public:
  TaskbarControls(HWND window, flutter::BinaryMessenger* messenger);
  ~TaskbarControls();

  std::optional<LRESULT> HandleWindowProc(UINT message, WPARAM wparam,
                                          LPARAM lparam);

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  HWND window_;
  ITaskbarList3* taskbar_ = nullptr;
  bool buttons_added_ = false;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif
