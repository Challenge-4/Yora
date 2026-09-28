#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kWindowTitle[] = L"Yora";
constexpr const wchar_t kSingleInstanceMutexName[] = L"Yora_SingleInstanceMutex";

bool ActivateExistingInstance() {
  HWND existing = ::FindWindow(kWindowClassName, kWindowTitle);
  if (!existing) {
    return false;
  }
  ::ShowWindow(existing, SW_RESTORE);
  ::SetForegroundWindow(existing);
  return true;
}

}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE single_instance_mutex =
      ::CreateMutex(nullptr, TRUE, kSingleInstanceMutexName);
  if (single_instance_mutex != nullptr &&
      ::GetLastError() == ERROR_ALREADY_EXISTS) {
    ActivateExistingInstance();
    ::CloseHandle(single_instance_mutex);
    return EXIT_SUCCESS;
  }

  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Yora", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  ::CloseHandle(single_instance_mutex);
  return EXIT_SUCCESS;
}
