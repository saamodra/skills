# Agent Skills Backup & Manager

A lightweight personal repository to manage, backup, and restore your AI agent skills across **Claude**, **Gemini / Antigravity**, and **OpenCode**.

## 💡 Concept

- **Custom Skills (Full Backup)**: Skills you created or customized (`parallel`, `team`, `editorial-imagegen`, etc.) are backed up in full into `skills/`.
- **Custom Configs**: Personal configs (like `AGENTS.md`) are backed up into `files/`.
- **External Skills (Reminder Inventory)**: Third-party skills (`hyperframes`, `cloudflare`, `instabox`, etc.) are tracked as a lightweight inventory table in `external-skills.md` without bloating the git repo with vendor code.

---

## 🚀 Quick Usage

### 1. Backup Custom Skills & Update Inventory
```bash
# Local backup
./sync.sh backup

# Or backup and push to GitHub in one command
./sync.sh backup --push "feat: update custom skills"
```

### 2. Add a New Custom Skill
```bash
./sync.sh add my-awesome-skill
```
This automatically registers the skill in `whitelist.txt` and backs it up into `skills/my-awesome-skill/`.

### 3. Check Status
```bash
./sync.sh status
```

### 4. Restore on a New Machine
```bash
git clone git@github.com:saamodra/skills.git ~/Projects/skills
cd ~/Projects/skills
./sync.sh install
```
This will:
1. Restore your custom skills to `~/.agents/skills/`.
2. Automatically create symlinks into **Claude** (`~/.claude/skills`) and **Gemini / Antigravity** (`~/.gemini/skills`, `~/.gemini/config/skills`).
3. Restore custom config files into `~/.config/...`.
4. Point you to `external-skills.md` if you wish to reinstall any upstream third-party skills.

---

## 📂 Repository Structure

- `whitelist.txt`: List of custom skills and config files to backup.
- `skills/`: The actual source code of your personal custom skills.
- `files/`: Backed up dotfiles / agent configurations.
- `external-skills.md`: Auto-generated table of third-party skills installed on your system.
- `sync.sh`: The all-in-one management script.
