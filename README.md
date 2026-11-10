# Thin Client / Kiosk RDP OS (x86_64 — BIOS + UEFI)

Sistema Operativo Linux minimale (basato su **Debian 12 Bookworm amd64**) progettato specificamente per trasformare qualsiasi PC, notebook o Mini-PC x86_64 in una postazione **Thin Client RDP in modalità Kiosk** dedicata ai Server Windows.

---

## Caratteristiche Principali

- **Compatibilità Universale PC e Mini-PC (`x86_64`)**: immagine `.iso` ibrida avviabile sia su macchine **Legacy BIOS** sia **UEFI** (64-bit e 32-bit), utilizzabile direttamente da chiavetta USB Live oppure **installabile su disco interno** (SSD SATA, M.2 NVMe, memoria integrata eMMC).
- **Rete Ethernet Automatica & Tastiera Italiana**:
  - Acquisizione automatica indirizzo IP, DNS e sincronizzazione oraria NTP tramite **DHCP su cavo Ethernet** (inclusi driver/firmware Intel e Realtek 1GbE/2.5GbE per Mini-PC).
  - Layout **tastiera italiana (`it` / `pc105`)** nativo in console, X11 e all'interno della sessione remota Windows (`0x00000410`).
- **Modalità Kiosk Pura (Zero Desktop)**:
  - Avvio diretto nell'interfaccia grafica dedicata senza desktop environment, senza barre delle applicazioni, senza scorciatoie di fuga (`Ctrl+Alt+Fn` e `Ctrl+Alt+Backspace` bloccati).
  - **Maschera grafica pulita** con i campi:
    - **Indirizzo Server Windows** (IP, hostname o `host:porta`)
    - **Dominio** *(opzionale)*
    - **Utente**
    - **Password** *(con icona mostra/nascondi)*
    - Pulsanti **Connetti**, **Pulisci**, **Riavvia** e **Spegni** (con conferma rapida anti-errore) + indicatore stato rete Ethernet in tempo reale.
- **Sessione FreeRDP a Tutto Schermo con NLA e Condivisione Periferiche**:
  - Connessione tramite `xfreerdp` a schermo intero (`/f`, `-toggle-fullscreen`), autenticazione **NLA (`/sec:nla`)**, adattamento dinamico risoluzione, audio e appunti abilitati.
  - **Chiavette e Dischi Esterni USB (`/drive:hotplug,*`)**: automount automatico a caldo in `/media/` per supporti FAT32, exFAT, NTFS ed ext4 (visibili subito in *Esplora File* sul Server Windows, escludendo la partizione di sistema).
  - **Stampanti Locali USB (`/printer` + CUPS)**: rilevamento e configurazione automatica delle stampanti USB (sia moderne driverless *IPP-over-USB* sia tradizionali tramite driver PPD con formato predefinito **A4**), inoltrate direttamente nella sessione remota Windows.
  - **Smart Card / Firma Digitale / CNS / CIE (`/smartcard` + `pcscd`)**: supporto integrato CCID/PC-SC per lettori di smart card e token crittografici USB.
  - **Memorizzazione automatica IP, Dominio e Utente**: **Indirizzo Server Windows**, **Dominio** e **Nome Utente** rimangono **memorizzati automaticamente** dopo la disconnessione e dopo lo spegnimento del PC **sia su Disco Interno sia su Chiavetta USB creata con Rufus o BalenaEtcher**, mentre **Password, appunti e file temporanei** vengono sempre cancellati a fine sessione con il cursore già pronto sul campo **Password**.
- **Sistema Immutabile (Read-Only SquashFS)**: anche quando installato su disco interno, il sistema operativo risiede in un'immagine compressa a sola lettura immune da spegnimenti improvvisi o mancanze di corrente.

---

## 1. Compilare gratuitamente la `.iso` nel Cloud (GitHub Actions)

Non è necessario avere Linux installato sul proprio PC per generare la `.iso`: il workflow [`.github/workflows/build-iso.yml`](.github/workflows/build-iso.yml) compila l'intero sistema operativo sui server gratuiti di GitHub.

### Passaggi rapidi

1. Crea un nuovo repository su [GitHub](https://github.com/new) (pubblico per minuti di compilazione gratuiti illimitati, oppure privato entro la quota gratuita mensile).
2. Carica questa cartella sul repository eseguendo da PowerShell / Terminale nella cartella del progetto:
   ```powershell
   git init
   git add .
   git commit -m "Initial commit: Thin Client RDP Kiosk OS"
   git branch -M main
   git remote add origin https://github.com/<TUO-UTENTE>/<NOME-REPO>.git
   git push -u origin main
   ```
3. Apri il repository su GitHub e vai nella scheda **Actions**:
   - La compilazione (**Build Thin Client RDP ISO**) partirà automaticamente a ogni push su `main` (oppure puoi avviarla manualmente cliccando **Run workflow**).
   - Durata media della compilazione cloud: **~6–10 minuti**.
4. Al termine del workflow (spunta verde):
   - Scorri in fondo al riepilogo dell'esecuzione fino alla sezione **Artifacts**.
   - Scarica **`thinclient-rdp-kiosk-amd64-iso`** ed estrai dallo `.zip` il file **`thinclient-rdp-kiosk-amd64.iso`**.
   - *(Opzionale)* Se pubblichi un tag versione (`git tag v1.0.0 && git push origin v1.0.0`), GitHub Actions creerà automaticamente anche una **Release** con il file `.iso` scaricabile direttamente senza archivio `.zip`.

---

## 2. Creare la Chiavetta USB (Rufus / BalenaEtcher)

1. Prepara una chiavetta USB da almeno **2 GB**.
2. Scrivi il file `thinclient-rdp-kiosk-amd64.iso` usando uno dei seguenti strumenti:
   - **BalenaEtcher**: seleziona il file `.iso`, scegli la chiavetta USB e clicca **Flash!**.
   - **Rufus** (su Windows): seleziona la chiavetta USB e il file `.iso`, lascia le impostazioni predefinite e clicca **Avvia** (funziona sia in modalità *Immagine ISO* sia in modalità *Immagine DD*).
3. **Impostazione BIOS/UEFI del PC o Mini-PC**:
   - Disabilita il **Secure Boot** nel BIOS/UEFI del PC/Mini-PC (necessario per i sistemi operativi Linux custom non firmati Microsoft).
   - Imposta il controller disco su **AHCI** (nel caso fosse su Intel RST/RAID).

---

## 3. Avvio da USB o Installazione su Disco Interno

All'accensione dalla chiavetta USB compare per 5 secondi il menu di avvio:

1. **`Avvia Thin Client RDP (Modalita Kiosk)`** *(predefinito)*: avvia direttamente il Thin Client in RAM/Live senza toccare il disco interno del PC.
2. **`Avvia Thin Client RDP (Compatibilita Video - nomodeset)`**: modalità ad alta compatibilità per schede video molto datate o particolari.
3. **`Installa Thin Client RDP su Disco Interno`**:
   - Avvia l'installatore guidato in italiano su disco interno (rileva automaticamente SSD SATA, NVMe e memorie eMMC escludendo la chiavetta USB).
   - Crea automaticamente la partizione d'avvio **ibrida BIOS + UEFI** e copia il sistema sul disco interno.
   - A fine procedura rimuovi la chiavetta USB: il Mini-PC/PC si avvierà in pochi secondi direttamente nella maschera Kiosk.

---

## 4. Memorizzazione Automatica (su Disco Interno e su Chiavetta Rufus)

Non appena inserisci **Indirizzo Server Windows**, **Dominio** e **Nome Utente** nella maschera grafica e premi **Connetti**, il sistema li salva automaticamente tramite `rdp-save-target` sia su **Disco Interno** (`RDPOS_ROOT`) sia su **Chiavetta USB creata con Rufus** (sia in modalità ISO/FAT32 sia in modalità DD grazie alla partizione dedicata `RDPOS_CFG` integrata nell'immagine):

- Alla disconnessione e ai successivi riavvii/spegnimenti, **IP Server**, **Dominio** e **Utente** saranno già compilati (ma sempre modificabili o azzerabili col pulsante **Pulisci**) e il cursore si posizionerà direttamente sul campo **Password**.
- La **Password** viene invece **sempre azzerata** a ogni disconnessione.

Se desideri preimpostare o modificare manualmente la configurazione anche da un altro PC, puoi modificare il file `rdp-kiosk.conf`:
  ```ini
  [kiosk]
  title = Postazione Thin Client RDP
  default_server = 192.168.1.10
  default_domain = AZIENDA
  default_user = mario.rossi
  clear_all_on_disconnect = false
  enable_usb_drives = true
  enable_printers = true
  enable_smartcard = true
  ```

---

## Struttura del Progetto

```text
.
├── .github/workflows/
│   └── build-iso.yml                 # Workflow GitHub Actions per generare la .iso nel cloud
├── build/
│   ├── build-iso.sh                  # Script di compilazione chroot Debian 12 + SquashFS + ISO ibrida
│   └── grub.cfg                      # Menu GRUB della Live USB (Kiosk, Safe Video, Installer)
├── overlay/
│   ├── etc/
│   │   ├── rdp-kiosk/kiosk.conf      # Configurazione base della maschera Kiosk
│   │   ├── sudoers.d/kiosk-power     # Permessi limitati a spegnimento, riavvio e installer
│   │   ├── systemd/system/...        # Autologin diretto su tty1
│   │   ├── X11/xorg.conf.d/...       # Tastiera italiana e blocco uscita VT/Xorg
│   │   └── xdg/openbox/rc.xml        # Window manager senza desktop né scorciatoie
│   └── usr/local/
│       ├── bin/kiosk-tty-launcher    # Avvio automatico Kiosk o Installer da tty1
│       ├── bin/kiosk-xsession        # Sessione grafica minimale X11 + Audio + Openbox
│       ├── bin/rdp-kiosk-ui          # Interfaccia GTK 3 Kiosk + lanciatore FreeRDP NLA
│       └── sbin/rdp-install-disk     # Installatore guidato italiano su disco interno (BIOS+UEFI)
├── .gitattributes                    # Forza fine riga Unix (LF) per script Linux
├── .gitignore
└── README.md
```
