# Agent Skills Backup

A simple local project to backup and install agent skills.

## Structure

- `skills.txt`: A configuration file containing a whitelist of agent skill names (one per line) that you want to backup or install.
- `backup.sh`: Reads `skills.txt` and securely copies the matching skill directories from `~/.agents/skills/` into this repository under a `skills/` directory.
- `install.sh`: Reads `skills.txt` and copies the backed-up skill directories from this repository's `skills/` directory back into `~/.agents/skills/`.

## Usage

### 1. Configuration
Open `skills.txt` and add the names of the skills you want to manage. For example:
```text
mr-description
another-awesome-skill
```

### 2. Backing Up Skills
Run the backup script to copy skills from your system into this repository:
```bash
./backup.sh
```
To also backup the `AGENTS.md` file (from `~/.agents/AGENTS.md`), use the `--agents-md` flag:
```bash
./backup.sh --agents-md
```

### 3. Installing Skills
Run the install script to copy skills from this repository to your system:
```bash
./install.sh
```
To also install the `AGENTS.md` file (to `~/.agents/AGENTS.md`), use the `--agents-md` flag:
```bash
./install.sh --agents-md
```
