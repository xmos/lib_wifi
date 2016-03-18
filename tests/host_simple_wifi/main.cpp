#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <xscope_endpoint.h>

typedef enum {
  STATE_DISCONNECTED,
  STATE_CONNECTED,
  STATE_INDEX,
  STATE_PASSWORD,
} state_t;

void strip_right(char *str) {
  // Trim trailing space
  size_t len = strlen(str);
  if (!len) {
    return;
  }

  char *end = str + strlen(str) - 1;
  while (end >= str && isspace(*end)) {
    end--;
  }

  // Write new null terminator
  *(end+1) = 0;
}

void xscope_print(unsigned long long timestamp,
                  unsigned int length,
                  unsigned char *data) {
  if (length) {
    for (int i = 0; i < length; i++) {
      printf("%c", *(&data[i]));
    }
  }
}

#define TOKENS " \n"
void handle_command_disconnected(char data[], state_t *state) {
  char *cmd = strtok(data, TOKENS);
  if (cmd &&
      ((strcmp(cmd, "c") == 0) ||
       (strcmp(data, "connect") == 0))) {
    const char *ip = strtok(NULL, TOKENS);
    const char *port = strtok(NULL, TOKENS);

    if (ip == NULL) {
      // Default values for both IP and port
      ip = "localhost";
      port = "10234";
    } else if (port == NULL) {
      // Only one argument passed, it must be port for localhost
      port = ip;
      ip = "localhost";
    }

    printf("Connecting to %s:%s... ", ip, port);
    int retval = xscope_ep_connect(ip, port);
    if (retval == XSCOPE_EP_SUCCESS) {
      printf("connected\n");
      *state = STATE_CONNECTED;
    } else {
      printf("failed\n");
    }
  } else {
    printf("Not connected - connect first, type '?' or 'h' for help\n");
  }
}

void handle_command_connected(char data[], state_t *state) {
  if ((data[0] == 'd' && data[1] == '\0') ||
      (strncmp(data, "disconnect ", 11) == 0)) {
    xscope_ep_disconnect();
    *state = STATE_DISCONNECTED;

  } else {
    int result = xscope_ep_request_upload(strlen(data)+1, (const unsigned char *)data);
    if (result != XSCOPE_EP_SUCCESS) {
      printf("Failed to send string, disconnecting\n");
      *state = STATE_DISCONNECTED;
    } else {
      if (strcmp(data, "join") == 0) {
        *state = STATE_INDEX;
        printf("Enter scan result index of network to join:\n");
      }
    }
  }
}

#ifdef _WIN32

#include <windows.h>
HANDLE hStdin
DWORD mode;

void disable_echo() {
  SetConsoleMode(hStdin, mode & (~ENABLE_ECHO_INPUT));
}

void restore_echo() {
  SetConsoleMode(hStdin, mode);
}

#else

#include <termios.h>
#include <unistd.h>
termios oldt;

void disable_echo() {
  termios newt = oldt;
  newt.c_lflag &= ~ECHO;
  tcsetattr(STDIN_FILENO, TCSANOW, &newt);
}

void restore_echo() {
  tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
}

#endif

void handle_command_index(char data[], state_t *state) {
  int result = xscope_ep_request_upload(strlen(data)+1, (const unsigned char *)data);
  if (result != XSCOPE_EP_SUCCESS) {
    printf("Failed to send string, disconnecting\n");
    *state = STATE_DISCONNECTED;
  } else {
    disable_echo();
    *state = STATE_PASSWORD;
    printf("Enter security key:\n");
  }
}

void handle_command_password(char data[], state_t *state) {
  int result = xscope_ep_request_upload(strlen(data)+1, (const unsigned char *)data);
  if (result != XSCOPE_EP_SUCCESS) {
    printf("Failed to send string, disconnecting\n");
    *state = STATE_DISCONNECTED;
  } else {
    *state = STATE_CONNECTED;
  }
  restore_echo();
}

void print_help() {
  printf("Controller:\n");
  printf(" c|connect [IP|localhost] [PORT] : connect to specified device\n");
  printf("    A default IP of 'localhost' and a default port of 10234 are used\n");
  printf("    if not specified. If only one argument is passed it is assumed to\n");
  printf("    be the port and the IP address is assumed to be 'localhost'\n");
  printf(" join : join a network\n");
  printf(" d|disconnect : disconnect current connection\n");
  printf(" h|?|help : print this help message\n");
  printf(" q|quit : quit\n");
  printf(" Anything else will be sent as a string to the controller\n");
}

#define STRLEN 1024

int main (void) {
  char data[STRLEN] = "";
  state_t state = STATE_DISCONNECTED;

  // Get the state of the terminal to be able to restore after getting the password
  #ifdef _WIN32
  hStdin = GetStdHandle(STD_INPUT_HANDLE);
  GetConsoleMode(hStdin, &mode);
  #else
  tcgetattr(STDIN_FILENO, &oldt);
  #endif

  xscope_ep_set_print_cb(xscope_print);

  printf("----- XMOS WIFI host controller -----\n");

  while (1) {
    if (fgets(data, STRLEN, stdin)) {
      // Strip the trailing '\n'
      strip_right(data);

      if (!strlen(data)) {
        // Don't send blank lines
        continue;
      }

      if ((strcmp(data, "q") == 0) ||
          (strcmp(data, "quit") == 0)) {
        // Don't send the quit to the target
        break;
      }

      if ((strcmp(data, "?") == 0) ||
          (strcmp(data, "h") == 0) ||
          (strcmp(data, "help") == 0)) {
        print_help();
        continue;
      }

      switch (state) {
      case STATE_DISCONNECTED:
        handle_command_disconnected(data, &state);
        break;
      case STATE_CONNECTED:
        handle_command_connected(data, &state);
        break;
      case STATE_INDEX:
        handle_command_index(data, &state);
        break;
      case STATE_PASSWORD:
        handle_command_password(data, &state);
        break;
      }
    }
  }
  return 0;
}
