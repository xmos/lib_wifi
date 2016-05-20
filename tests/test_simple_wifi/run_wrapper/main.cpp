/*
 * xscope host application to receive SSL information and write it to
 * premaster.txt which can then be used by Wireshark to decode packets.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <unistd.h>
#include <signal.h>
#include <string.h>

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


#define STRLEN 1024

int main (int argc, char *argv[])
{
  // Get the state of the terminal to be able to restore after getting the password
  #ifdef _WIN32
  hStdin = GetStdHandle(STD_INPUT_HANDLE);
  GetConsoleMode(hStdin, &mode);
  #else
  tcgetattr(STDIN_FILENO, &oldt);
  #endif

  if (argc < 2) {
    printf("usage: %s NETWORK_NAME\n", argv[0]);
    return 1;
  }

  char *network_name = argv[1];
  char key[STRLEN];

  printf("Please enter the network password:\n");
  disable_echo();
  fgets(key, STRLEN, stdin);
  restore_echo();

  // Remove newline from password
  size_t key_len = strlen(key);
  if ((key_len > 0) && (key[key_len-1] == '\n')) {
    key[--key_len] = '\0';
  }

  // Build command string
  char cmd[STRLEN] = "./run.sh \"";
  strcat(cmd, network_name);
  strcat(cmd, "\" \"");
  strcat(cmd, key);
  strcat(cmd, "\"");
  system(cmd);

  return 0;
}
