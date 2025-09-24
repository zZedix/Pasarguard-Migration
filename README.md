# Marzban ➜ Pasarguard Migration Script ( SQLite Only )

This script migrates your **Marzban** configuration and data to the **[Pasarguard Panel](https://github.com/PasarGuard/panel)**.

> ⚠️ **Important**  
> Pasarguard Panel is currently in **beta**.  
> Before running this script, create a **full backup** or **server snapshot**.

---

## 1️⃣ Install Pasarguard First

Before migrating, install Pasarguard using the instructions from the official repository:  
➡️ [https://github.com/PasarGuard/panel](https://github.com/PasarGuard/panel)

Make sure Pasarguard is installed and running correctly before you proceed.

---

## 2️⃣ Quick Run (One-Liner)

Once Pasarguard is installed, you can run the migration directly:

```bash
curl -fsSL https://raw.githubusercontent.com/zZedix/Pasarguard-Migration/main/script.sh | sudo bash
