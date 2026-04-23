# OpenCode Handoff

Open OpenCode in the installed runtime directory:

```bash
cd ~/.local/share/todo_wallpaper
opencode
```

Paste this prompt:

```text
I installed todo_wallpaper in ~/.local/share/todo_wallpaper using --opencode. I am now using OpenCode inside that installed runtime directory. Treat ~/.local/share/todo_wallpaper as the local runtime toolkit for this wallpaper workflow, not as the user's task repository. Before doing anything else, read ~/.config/todo_wallpaper/config.env and summarize the current setup: mode, configured TODO file path, configured wallpaper output path, configured box position, configured backend, and the backend/session you actually detect on this machine. Use only the local scripts in ~/.local/share/todo_wallpaper as the supported primitives: scripts/render_todo_wallpaper.py for rendering, scripts/apply_wallpaper.sh for wallpaper apply or clear, scripts/run_wallpaper_job.sh for the render-and-apply flow, and uninstall.sh for cleanup. Keep the real TODO markdown outside this runtime directory unless I explicitly ask otherwise. Respect the priority syntax already supported by the renderer: markdown checkboxes like [H], [M], or [ ] at the start of a task, for example '- [H] urgent task' and '- [M] important task'. Do not treat this as the self-contained watcher flow unless the config says so. After you inspect the config and local scripts, explain clearly what is already installed, what is safe to change, what commands or actions are available from this setup, and what the next sensible step is. If I already asked for an action, carry it out using this installed runtime instead of re-deriving the architecture.
```
