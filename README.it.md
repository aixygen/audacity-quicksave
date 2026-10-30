# Audacity Quick Save

**Un vero "Salva" per Audacity su Linux.** Premi una scorciatoia e l'audio che stai modificando viene riscritto sul file originale, nello stesso formato, con la stessa qualità, gli stessi tag e la stessa copertina. Una copia della versione precedente viene conservata in automatico.

[Read in English](README.md)

---

## Perché

Audacity non modifica i file direttamente. Quando apri un MP3 ne importa una copia, e l'unico modo per riportare le modifiche nel file è **File > Esporta audio**, scegliendo ogni volta cartella, nome, formato e opzioni, e poi confermando la sovrascrittura.

Sul forum di Audacity lo chiedono da anni e ancora non c'è. Audacity Quick Save risolve questo.

## Cosa fa

- **Una scorciatoia, nessuna finestra.** Di base Ctrl+Alt+S.
- **Mantiene le caratteristiche dell'originale**, cioè formato, codec, bitrate (CBR o VBR), frequenza di campionamento, profondità di bit, canali.
- **Mantiene i metadati**, cioè tag, copertina, capitoli, versione ID3.
- **Senza perdite dove conta.** L'audio esce da Audacity in 32 bit float, quindi WAV, FLAC e gli altri formati lossless restano identici bit per bit se non li tocchi.
- **Non perdi mai il file.** La versione precedente finisce in una cartella di backup (tiene le ultime 20) e l'originale viene sostituito in un'unica operazione atomica.
- **Messaggi in italiano o in inglese**, in base alla lingua del sistema.

### Formati supportati

| Formato | Codec | Note |
|---|---|---|
| MP3 | LAME | bitrate CBR identico, qualità VBR letta dall'intestazione LAME se presente, ID3v2.3/2.4 e ID3v1 mantenuti |
| FLAC | FLAC | 16 o 24 bit |
| WAV, AIFF, W64 | PCM | stesso formato dei campioni (16/24/32 bit, float) |
| M4A / MP4 | AAC, ALAC | per HE-AAC serve ffmpeg con libfdk_aac, altrimenti usa LC |
| OGG | Vorbis | |
| OPUS | Opus | |
| WV | WavPack | |
| MP2, AC3, WMA | | supporto di base |

I file con più di 2 canali per ora non sono supportati.

## Requisiti

- Linux (testato su Ubuntu 24.04 con GNOME, Audacity 3.4.2 da apt e 3.7.8 da Flathub)
- **Audacity 3.x** con il modulo `mod-script-pipe` (incluso nei pacchetti Ubuntu/Debian e nelle versioni ufficiali)
- Python 3.8 o successivo (già presente nella maggior parte delle distribuzioni)
- ffmpeg e ffprobe, si installano con `sudo apt install ffmpeg`

> Audacity 4 non include più `mod-script-pipe`, quindi per ora non è supportato.

## Installazione

```bash
git clone https://github.com/aixygen/audacity-quicksave.git
cd audacity-quicksave
./install.sh
```

L'installer copia lo script in `~/.local/bin` e, su GNOME, crea la scorciatoia **Ctrl+Alt+S**. Per usare un altro tasto lancia `./install.sh --shortcut '<Super>s'`. Con `--no-shortcut` la salti e puoi associare tu `~/.local/bin/audacity-quicksave` a un tasto nelle impostazioni della tastiera del tuo desktop (KDE, XFCE, Cinnamon...).

Poi **attiva una volta il modulo di scripting**

1. Apri Audacity
2. Vai in **Modifica > Preferenze > Moduli**
3. Imposta **mod-script-pipe** su **Abilitato**
4. Riavvia Audacity

## Uso

1. Apri un file audio in Audacity (File > Apri, doppio clic, trascinamento)
2. Modificalo
3. Premi **Ctrl+Alt+S**

Una notifica conferma il salvataggio, per esempio *Salvato brano.mp3, MP3 320 kbps, 44.1 kHz, stereo*.

Puoi lanciare `audacity-quicksave` anche da terminale.

### Backup

A ogni salvataggio la versione precedente viene copiata in `~/.local/state/audacity-quicksave/backups`, con data e ora nel nome. Vengono tenute le 20 più recenti. Per cambiare queste impostazioni copia [`config.example.ini`](config.example.ini) in `~/.config/audacity-quicksave/config.ini`.

## Come funziona

1. Il modulo `mod-script-pipe` di Audacity permette ad altri programmi di mandargli comandi tramite due pipe. La scorciatoia si collega solo per il tempo del salvataggio.
2. Lo script trova il file originale nella lista dei *File recenti* di Audacity, confrontandola con i nomi delle tracce del progetto attivo.
3. Legge le caratteristiche dell'originale con `ffprobe`.
4. Fa esportare ad Audacity tutto il progetto in un WAV temporaneo a 32 bit float, accanto all'originale e alla sua stessa frequenza.
5. `ffmpeg` ricodifica quel WAV con il codec e le impostazioni dell'originale, copiando tag e copertina.
6. L'originale finisce nei backup e viene sostituito con un'unica rinomina atomica.
7. Lo script si scollega. È importante, perché finché uno script resta collegato Audacity non riesce a chiudersi correttamente.

## Da sapere

- **Salva la finestra di Audacity attiva.** La scorciatoia è globale, quindi se la premi mentre sei in un'altra app salva comunque l'ultimo progetto di Audacity che hai usato.
- **Lascia il nome della traccia uguale al nome del file.** È così che viene riconosciuto il file originale. Se rinomini la traccia, lo strumento non tira a indovinare e te lo dice.
- **I formati con perdita vengono ricodificati a ogni salvataggio**, come con qualsiasi editor. Se devi fare molti giri di modifiche, lavora su una copia WAV o FLAC e converti alla fine.
- **Selezione e frequenza del progetto cambiano.** Prima di esportare viene selezionato tutto e la frequenza del progetto viene impostata su quella del file originale.
- **Bitrate approssimati.** Per AAC, Vorbis e Opus il file non contiene il bitrate nominale, quindi quello misurato viene arrotondato al valore standard più vicino (243 kbps diventa 256). Per gli MP3 VBR senza intestazione LAME con la qualità, il livello VBR viene stimato dal bitrate medio.
- **Uno script alla volta.** Non usare altri strumenti basati su `mod-script-pipe` proprio nel momento in cui salvi.
- **Flatpak e Snap.** Testato con la versione Flatpak di Flathub di Audacity 3.7.8. Se la sandbox ha una `/tmp` privata, le pipe vengono cercate tramite `/proc/<pid>/root/tmp`. Snap non è testato, le segnalazioni sono benvenute.

## Problemi

**"Audacity non è aperto, oppure mod-script-pipe non è attivo"**. Controlla Modifica > Preferenze > Moduli e riavvia Audacity.

**"Audacity non risponde agli script"**. Riprova. Se succede ancora, riavvia Audacity.

**Altro**. Il log è in `~/.local/state/audacity-quicksave/quicksave.log`. Apri una issue allegandolo.

## Disinstallazione

```bash
./uninstall.sh
```

I backup non vengono cancellati.

## Licenza

[MIT](LICENSE)
