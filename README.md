# Agent Skills Backup

A simple local project to backup and install agent skills.

## Structure

- `whitelist.txt`: A configuration file containing a whitelist of items to backup or install. You can provide:
  - **Skill names** (e.g., `mr-description`), which will be backed up from `~/.agents/skills/` into the `skills/` directory.
  - **Absolute file paths** (e.g., `~/.agents/AGENTS.md`), which will be backed up into the `files/` directory.
- `backup.sh`: Reads `whitelist.txt` and securely copies the matching skills and files into this repository.
- `install.sh`: Reads `whitelist.txt` and copies the backed-up skills and files from this repository back into their original locations on your system.

## Usage

### 1. Configuration
Open `whitelist.txt` and add the names of the skills or absolute paths you want to manage. For example:
```text
mr-description
another-awesome-skill
~/.agents/AGENTS.md
```

### 2. Backing Up Skills and Files
Run the backup script to copy items from your system into this repository:
```bash
./backup.sh
```

### 3. Installing Skills and Files
Run the install script to copy items from this repository to your system:
```bash
./install.sh
```
