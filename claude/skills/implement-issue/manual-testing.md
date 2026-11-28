# Manual verification recipes

Use these only when the repo doesn't document its own way to run and check the
app. Repo instructions always win. Each recipe ends with evidence you can quote:
captured output, an HTTP response or a screenshot.

## Interactive programs (TUIs, editors, REPLs) with tmux

tmux lets you start an interactive program, type into it and read the screen,
without a real terminal.

```bash
S=verify-$$                                     # unique session name
tmux new-session -d -s "$S" -x 200 -y 50        # detached, fixed size for stable output
tmux send-keys -t "$S" '<command to start the app>' Enter
sleep 1                                         # give it time to draw; poll instead if slow
tmux capture-pane -t "$S" -p                    # print the visible screen
tmux send-keys -t "$S" 'some input' Enter       # type text
tmux send-keys -t "$S" Escape                   # special keys: Escape, Enter, Tab, C-c, Up, Down...
tmux capture-pane -t "$S" -p -S -200            # include 200 lines of scrollback
tmux kill-session -t "$S"                       # always clean up
```

Tips:
- Poll for the expected text instead of long sleeps:
  `for i in $(seq 20); do tmux capture-pane -t "$S" -p | grep -q 'READY' && break; sleep 0.5; done`.
- Use a throwaway config/home so the user's real setup doesn't skew the result or
  get changed. For Neovim, for example: `nvim --clean -u <minimal-init>`, or point
  `XDG_CONFIG_HOME`/`XDG_DATA_HOME`/`XDG_STATE_HOME` at a temp directory and load
  the plugin from the working tree.
- Many editors and REPLs can also run headless with commands and print results,
  e.g. `nvim --headless -c '<cmd>' -c 'qa!'`. That is easier to assert on; use tmux
  when you need to see what is drawn on screen or how it reacts to keys.
- Check error output as well as the happy path: messages, logs, `:messages` in Vim.
- Always `kill-session`, even when a step fails.

## Command-line tools

Build the binary from the working tree, then run the commands from the acceptance
criteria. Check the output and the exit code (`echo $?`). Try bad input and
`--help`. Run in a temp directory so you don't leave files behind.

## Servers and APIs

Start the server in the background (or in a tmux session) on a free port, wait
until it is ready (poll a health endpoint), then exercise the endpoints with
`curl -sS -i`. Check the status codes, bodies and logs, including error cases.
Stop the server when you are done.

## Web UIs

If browser automation tools are available, open the page, follow the user flow
and take screenshots as evidence. If not, check the server-rendered output and the
API calls with curl, and list the visual checks a human should do.

## Libraries

Write a tiny throwaway program or script outside the repo (or in a temp
directory) that uses the public API the way the issue describes, and run it.
Don't commit it.
