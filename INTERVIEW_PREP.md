# Axilink — Interview Prep (Q&A)

Smartphone-Controlled Desktop System with Interactive Screen Mirroring.
**Stack:** Spring Boot · STOMP over WebSocket · Flutter · Python · on-device ML Kit / native Speech.

Study by theme. Say answers in your own words — don't memorize verbatim. The two
bug stories (coordinate letterbox fix, OCR stall) and the streaming tradeoffs are
your highest-value material.

---

## 1. Architecture & high-level

**Q: Walk me through the architecture.**
Three parts: a **Flutter phone app**, a **Spring Boot relay server**, and a **Python desktop client**. The phone and desktop never talk directly — both connect to the Spring Boot server over **WebSocket using STOMP**, and join a session by a shared 4-digit code. The phone publishes control/touch messages; the server relays them to the desktop on a topic keyed by session code; the desktop executes them with `pyautogui`. For screen mirroring it's reversed: the desktop captures the screen and streams JPEG frames back to the phone.

**Q: Why a relay server instead of phone↔desktop directly?**
Direct P2P needs both devices reachable on the same network or NAT traversal (STUN/TURN/hole-punching). A central relay means it works over the internet from anywhere with zero network config — the phone scans a QR with a session code and connects to a known cloud server. Tradeoff: extra hop adds latency and the server is a bottleneck/cost, but for an MVP the simplicity wins. (Honest improvement: WebRTC for true low-latency P2P.)

**Q: What are the two modes?**
**Control mode** — phone is a gyroscope air-mouse + trackpad + keyboard (sends `dx/dy`, clicks, scroll, typed text). **Mirror mode** — desktop streams its screen to the phone and the phone sends back touch coordinates as clicks. A `mode` message switches between them.

---

## 2. WebSocket / STOMP

**Q: Why STOMP over raw WebSocket?**
Raw WebSocket is just a byte pipe — I'd have to invent my own routing/addressing. STOMP gives me **pub/sub semantics on top of WebSocket**: destinations like `/topic/screen/{code}`, subscriptions, and Spring's broker handles fan-out. The session code in the destination cleanly isolates one phone-desktop pair from another.

**Q: Explain `/app` vs `/topic`.**
`/app` is the **application prefix** — messages there hit a Spring `@MessageMapping` controller method (server logic runs). `/topic` is the **broker prefix** — messages there get broadcast to all subscribers. So the phone sends to `/app/touch/{code}`, the controller processes and republishes to `/topic/touch/{code}`, which the desktop is subscribed to.

**Q: What broker are you using?**
Spring's **in-memory SimpleBroker** (`enableSimpleBroker("/topic")`). It's fine for a single server instance. For horizontal scaling I'd switch to a **full STOMP broker like RabbitMQ** so topics work across multiple server nodes.

**Q: How did you handle large messages / throughput?**
Two things in `WebSocketConfig`: I raised the **message buffer to 8 MB** (a lossless OCR screenshot can be several MB) and **sized the inbound/outbound thread pools** (core 8, max 32) because Spring's default channels are single-threaded — that becomes the ceiling once several frames stream concurrently. I also set a 20s send time limit so a stalled subscriber gets dropped instead of backing up memory.

---

## 3. Touch coordinate mapping (strongest bug story)

**Q: How do you map a touch on the phone to a click on the desktop?**
I send coordinates as **percentages** (`xPercent`, `yPercent` from 0–1), not pixels — so they're resolution-independent. The desktop multiplies by the target monitor's width/height (plus the monitor's offset for multi-monitor) to get an absolute pixel position.

**Q: There was a bug here — tell me about it.**
Originally I had a hardcoded `scaling_factor_x = 1.16` on the desktop. It worked perfectly on my phone but was wrong on others. The root cause: the mirrored image is shown with `BoxFit.contain`, which **letterboxes** — black bars appear when the phone's aspect ratio ≠ the desktop's. But my touch listener covered the *whole screen*, so I was computing the percentage against the full screen while the image only filled part of it. The `1.16` was a manual patch for the pillarbox width on my specific phone. I fixed it by computing the **actual displayed image rectangle** (accounting for the letterbox offset) and measuring the percentage against *that*. Now it's device-independent and I deleted the magic number. I also dropped touches that land in the black bars.

**Q: Why percentages instead of sending pixel coordinates?**
The phone has no idea of the desktop's resolution, and the image is scaled down for streaming. Percentages decouple the two — any phone size maps to any monitor size with no negotiation.

---

## 4. Screen mirroring / streaming

**Q: How does screen mirroring work end to end?**
Desktop loop (in a background thread): capture the monitor with **`mss`**, resize, encode to **JPEG**, base64, and send one message per frame to `/app/screen/{code}`. The server relays to `/topic/screen/{code}`; the phone base64-decodes and draws it with `Image.memory` and `gaplessPlayback` for smooth updates.

**Q: Are you sending full frames or deltas?**
**Full frames** — each message is a complete JPEG of the whole screen, independent of the last. No diffing. It's simpler and robust; the tradeoff is a static screen costs the same bandwidth as full motion. The natural next step is **delta/tile encoding** with periodic keyframes.

**Q: How do you control bandwidth? (the 45% claim)**
Three adaptive mechanisms: **adaptive JPEG quality** (40–85, targeting ~150 KB/frame), **frame skipping** to hold the target FPS (5–25), and an **emergency downscale** if a frame still exceeds ~900 KB. The resolution itself is adjustable (resize factor, ~480p–1080p). Together these cut bandwidth ~45% vs sending max-quality full-res frames.

**Q: Why JPEG and not PNG or H.264?**
JPEG: great compression for photographic/screen content, lossy but tunable, and trivially fast to encode per-frame with no inter-frame state. PNG is lossless but far larger (I only use it for OCR screenshots where text sharpness matters). **H.264/H.265 would be the real upgrade** — temporal compression would massively beat per-frame JPEG — but it needs an encoder/decoder pipeline and adds latency/complexity.

---

## 4b. Explaining the 45% and frame skipping (simple words)

**Q: What does "frame skipping" actually do?**
I set a target speed, e.g. 15 frames per second = send one image every ~66 ms. Two cases: (1) if the next frame is ready *too soon*, I wait instead of sending extra frames, so I never send more than the target — fewer frames, fewer bytes. (2) If capturing + compressing + sending one frame takes *longer* than the budget (the computer is busy), I **drop the next frame to catch up** instead of building a backlog. Fewer frames sent = less bandwidth and lower lag.
*(Note: my code does NOT detect whether the screen changed — it skips based on speed/load only. "Only send when the screen changes" is the future delta-encoding idea, not what I built.)*

**Q: How did you measure the bandwidth saving?**
Two numbers describe the stream: **KB per frame** (size of one compressed image) and **FPS** (frames sent per second). Multiply them to get bandwidth in KB/second:
`bandwidth = KB per frame × FPS`. The desktop client prints both live (the perf label shows `Size: …KB` and `FPS`). I read those for a full-resolution / full-quality baseline and for the adaptive setup, multiplied each, and compared.

**Q: How do you get to ~45%?**
Percentage drop = `(before − after) ÷ before × 100`.
Example: baseline **4000 KB/s**, optimized **2200 KB/s** → saved 1800 → `1800 ÷ 4000 = 45%`.
It means the optimized stream sends a bit less than half the data of the baseline. The saving comes from three stacked levers: **smaller frames** (resolution downscale), **lighter frames** (adaptive JPEG quality, ~150 KB target), and **fewer frames** (frame skipping).

---

## 5. Latency & performance

**Q: How do you hit ~50ms latency?**
Small per-message payloads (chunked/compressed frames), parallelized server channels, JPEG over heavier codecs, and `gaplessPlayback` on the client to avoid flicker. Control messages (`dx/dy`, clicks) are tiny so they're near-instant; the latency budget is mostly the mirror frames.

**Q: Where's the latency bottleneck?**
The mirror path: capture + encode on desktop, the relay hop, and decode/draw on the phone. The relay adds a round-trip vs P2P. Encoding full JPEGs every frame is CPU work too.

---

## 6. On-device AI (OCR + speech)

**Q: You used Azure then moved to on-device — why?**
Azure worked but meant **API keys, per-call cost, network latency, and a round-trip** (record → upload → wait). I replaced **Azure Vision OCR with Google ML Kit** (on-device text recognition) and **Azure Speech with the native speech engine** via `speech_to_text`. Result: no keys, no cost, lower latency, works offline, and one less external dependency.

**Q: Tell me about the OCR being "stuck loading." (second bug story)**
The OCR spinner hung forever. Two causes: (1) the app requested a high-quality screenshot over STOMP, but the **backend had no handler** for that destination and the **desktop never subscribed** to it — so it always waited the full 10-second timeout before falling back. (2) The ML Kit wrapper only fired its callback **when text was found**, so a blank frame left `_isProcessing = true` permanently. I removed the pointless network round-trip — the mirror frame is already on the phone, so I OCR it locally and instantly — and I drove the UI off the **awaited result** instead of the callback, so the spinner can never get stuck.

**Q: Is on-device OCR/speech as accurate as Azure?**
Slightly less in hard cases, but good enough for UI text and short commands — and the latency/cost/offline wins outweigh it for this app. For speech I kept the same command-parsing grammar, so behavior is unchanged from the user's view.

---

## 7. Backend / Spring specifics

**Q: How are sessions managed?**
A random **4-digit code** generated on the desktop, shown as a QR. The phone scans it (or types it) and both subscribe to topics keyed by that code. The server is stateless about sessions — the code *is* the routing key. (Weakness: only 9000 codes, no auth — see security.)

**Q: How does the server know which desktop to send a phone's click to?**
It doesn't track connections — it just **republishes to the topic for that session code**, and whichever desktop subscribed to that code receives it. Pub/sub by convention, not a connection registry.

---

## 8. Security & production (they *will* ask)

**Q: What are the security weaknesses?**
Honestly several: **4-digit codes are guessable** (brute-forceable, no rate limiting), **no authentication** on sessions, and anyone who knows a code could hijack a session. `setAllowedOrigins("*")` is permissive. For production I'd add: longer/cryptographic session tokens, auth, rate limiting, TLS (already `wss` in cloud mode), and per-session access control.

**Q: How would you scale this to many users?**
Replace the in-memory SimpleBroker with **RabbitMQ/an external STOMP broker** so multiple server instances share topics, put the servers behind a load balancer with **sticky sessions** (WebSocket connections are stateful), and offload frame relay. Eventually move mirroring to **WebRTC** to take frame traffic off the server entirely.

---

## 9. "What would you improve?" (have 2–3 ready)

1. **Delta/tile frame encoding + keyframes** — biggest bandwidth win for static screens.
2. **WebRTC for the mirror path** — P2P, lower latency, takes load off the relay.
3. **H.264 hardware encoding** instead of per-frame JPEG.
4. **Stronger session security** — tokens + auth + rate limiting.

---

## Quick-fire facts (memorize these numbers)

- Latency target: **~50 ms** end to end.
- Mirroring: **480p–1080p**, **5–25 FPS**, JPEG, frame skipping → **~45% bandwidth reduction**.
- Adaptive JPEG quality: **40–85**, target **~150 KB/frame**, hard cap **~900 KB**, emergency downscale 10%.
- WebSocket message buffer: **8 MB**. Channel thread pools: core **8**, max **32**. Send time limit **20 s**.
- Session code: **4-digit** random (1000–9999), shared via QR.
- Capture lib: **mss** · Control lib: **pyautogui** · OCR: **Google ML Kit** · Speech: **native `speech_to_text`**.
- Broker: in-memory **SimpleBroker** on `/topic`, app prefix `/app`.

---

## Glossary — jargon in plain English

Read this once and the answers above will make sense. Each term = simple meaning + analogy.

### Networking / WebSocket terms

- **Baseline** — the "before" version you compare against. To prove an optimization helped, you measure the un-optimized version (the baseline) and the optimized one, and compare. *Analogy: your weight before a diet.*
- **WebSocket** — a connection between two computers that **stays open** so both sides can send messages anytime, instantly. Normal web (HTTP) is "ask a question, get one answer, hang up." WebSocket is "keep the phone line open and talk freely." *Perfect for live control/streaming.*
- **Byte pipe** — means WebSocket only moves **raw bytes**; it has no idea what they mean or where they should go. It's a dumb tube. *Analogy: a water pipe moves water but doesn't sort it.* That's why you add STOMP on top to give the bytes structure and addresses.
- **STOMP** — a simple set of rules (a "protocol") layered on WebSocket that adds **addresses and pub/sub**. It turns the dumb byte pipe into a postal system with named mailboxes (destinations). *STOMP = Simple Text Oriented Messaging Protocol.*
- **Protocol** — an agreed set of rules for how two sides talk so they understand each other. *Analogy: both people agreeing to speak English.*
- **Pub/Sub (publish / subscribe)** — a messaging style: senders **publish** messages to a named channel; anyone **subscribed** to that channel receives them. Sender and receiver don't know each other directly — they just share a channel name. *Analogy: a radio station broadcasts (publish); anyone tuned to that frequency hears it (subscribe).* In Axilink the channel name contains the session code, so only the right phone+desktop pair share it.
- **Semantics** — just means "the meaning / behavior of something." "Pub/sub semantics" = "the publish-subscribe behavior." *Don't be scared of the word — it = "what it actually does."*
- **Topic** — the named channel in pub/sub (e.g. `/topic/screen/1234`). Subscribers to that topic get its messages.
- **Destination** — the address you send a message to in STOMP (a topic or an app endpoint). *Like an email address for a message.*
- **Broker** — the piece of software that receives published messages and **delivers them to all subscribers**. The post office of pub/sub. Yours is Spring's built-in **SimpleBroker** (lives in memory, one server). **RabbitMQ** is a heavier external broker you'd use to scale across many servers.
- **Relay server** — a middleman server that both devices connect to, which **passes messages between them**. The phone and desktop don't talk directly; the server relays. *Analogy: two people who don't have each other's number both text a mutual friend who forwards messages.*
- **P2P (peer-to-peer)** — the opposite: the two devices talk **directly**, no middleman. Lower latency but harder to set up across the internet.
- **NAT traversal / STUN / TURN / hole-punching** — the tricky techniques needed to make P2P work when devices are behind home routers (which hide their real address). You **avoided all this** by using a relay server — a point in your favor for simplicity.
- **Payload** — the actual data inside a message (ignoring the address/headers). *Analogy: the letter inside the envelope.* Your control payloads (`{dx, dy}`) are tiny; frame payloads (a JPEG) are big.
- **Serialization / JSON** — turning a data object into text you can send over the network (and back). **JSON** is the common text format, like `{"action":"click"}`. *Analogy: flat-packing furniture to ship it, then rebuilding it.*
- **Fan-out** — one message getting copied out to many subscribers. *Analogy: one announcement heard by a whole room.*

### Speed / size terms

- **Latency** — **delay**: how long from doing something to seeing the result. Measured in milliseconds (ms). Lower = snappier. *Analogy: the lag between flipping a switch and the light turning on.*
- **End-to-end latency** — the **total** delay across the whole path (phone → server → desktop → action), not just one hop.
- **Round-trip** — message goes there **and** the response comes back. Round-trip time = the full there-and-back delay.
- **Bandwidth / throughput** — **how much data per second** you push (e.g. KB/s or MB/s). Lower bandwidth = cheaper, works on weaker networks. *Analogy: how much water flows through the pipe per second.* (Latency = delay; bandwidth = volume — they're different things.)
- **Buffer** — a temporary holding area for data in transit. You raised the message **buffer** to 8 MB so big OCR screenshots fit. *Analogy: a waiting room; if it's too small, big arrivals get rejected.*
- **Thread pool / channel** — threads are workers that do tasks in parallel. Spring's default message channel had **one** worker (single-threaded) = a bottleneck. You gave it a **pool** of 8–32 workers so many frames process at once. *Analogy: opening more checkout lanes so the queue moves faster.*
- **Single-threaded bottleneck** — when everything must pass through one worker, so it's the slow point no matter how fast everything else is.

### Streaming / image terms

- **Frame** — one single image in the video stream. A "screen frame" = one screenshot.
- **FPS (frames per second)** — how many images you send each second. 15 FPS = 15 images/second.
- **Frame skipping** — deliberately **not sending** some frames (to hold the target FPS or when the PC is overloaded). Fewer frames = less data + no backlog.
- **JPEG vs PNG** — two image formats. **JPEG** = smaller files, slightly **lossy** (throws away detail you barely notice) — great for streaming. **PNG** = **lossless** (perfect quality) but big — you use it only for OCR screenshots where sharp text matters.
- **Lossy / lossless** — lossy = sacrifices some quality to shrink size (JPEG); lossless = keeps every pixel exactly (PNG).
- **Compression / quality (40–85)** — squeezing the image smaller. Lower "quality" number = smaller file but blurrier. You auto-tune it to hit ~150 KB per frame.
- **Adaptive** — automatically adjusts to conditions. **Adaptive quality/streaming** = the app changes resolution/quality/FPS on the fly based on size and performance, instead of using fixed settings.
- **Delta / tile encoding (the future idea)** — only send the **parts of the screen that changed** since the last frame, instead of the whole screen. Big saving on static screens. **You did NOT build this** — say it as a future improvement.
- **Keyframe** — a full, complete frame sent occasionally as a fresh reference (used with delta encoding so the client can re-sync). *Analogy: a clean save point.*

### Flutter / UI terms

- **Aspect ratio** — the width-to-height shape of a screen, e.g. 16:9. Phones and monitors often differ.
- **BoxFit.contain** — a Flutter setting that fits the whole image inside the area **without cropping**, which leaves empty bars when shapes don't match.
- **Letterbox / pillarbox** — the **black bars**. Letterbox = bars on **top/bottom**; pillarbox = bars on **left/right**. They appear because of aspect-ratio mismatch — the cause of your touch-mapping bug.
- **Normalized / percentage coordinates** — storing a position as 0–1 (e.g. 0.5 = halfway) instead of pixels, so it works on **any** screen size. *Analogy: "halfway across" works on any size of paper; "12 cm across" doesn't.*
- **Callback** — a function that runs **later, when something finishes** (e.g. "call me back when the OCR result is ready"). Your OCR bug was a callback that **never fired**, so the spinner spun forever.
- **Async / await** — handling things that take time (network, file, OCR) **without freezing the app**. `await` = "wait for this to finish, then continue," but other things keep running meanwhile.

### AI terms

- **OCR (Optical Character Recognition)** — reading **text out of an image** (turning a picture of words into actual text you can copy).
- **On-device / on-device inference** — the AI runs **on the phone itself**, not on a cloud server. Benefits: no API key, no cost, no network delay, works offline, more private.
- **ML Kit** — Google's on-device machine-learning library (you use its OCR).
- **Speech-to-Text (STT)** — converting spoken audio into text (for your voice commands).
- **Native engine** — the phone's **built-in** capability (Android/iOS provide a speech recognizer) — you use that instead of Azure.

### Scaling / security terms

- **Horizontal scaling** — handling more users by adding **more servers** (vs. "vertical" = one bigger server).
- **Load balancer** — a traffic cop that spreads incoming connections across multiple servers.
- **Sticky sessions** — making sure a user **stays connected to the same server** for their whole session. Needed for WebSockets because the connection is ongoing/stateful.
- **Stateful vs stateless** — stateful = the server remembers an ongoing connection/context (WebSocket); stateless = each request is independent (normal HTTP).
- **TLS / `wss`** — encryption for the connection. `ws://` = unencrypted, `wss://` = encrypted (secure). *Like `http` vs `https`.*
- **Authentication / rate limiting** — auth = proving who you are; rate limiting = capping how many attempts someone can make (stops brute-forcing your 4-digit code).

### General terms

- **Gyroscope** — the phone sensor that detects tilt/rotation; you use it for air-mouse movement.
- **`pyautogui`** — Python library that controls the mouse/keyboard on the desktop (moves cursor, clicks, types).
- **`mss`** — fast Python library for **screen capture** (taking the screenshots you stream).
- **Magic number** — a hardcoded value with no clear reason (your old `1.16`). Seen as bad practice; replacing it with real logic is a plus.

---

## Super-simple one-liners (ELI5 cheat sheet)

The shortest possible meaning for each term — for fast revision.

### Networking / WebSocket
- **Baseline** → the "before" version you compare against.
- **WebSocket** → an always-open line so both sides can talk anytime.
- **Byte pipe** → a dumb tube that moves data but doesn't understand it.
- **STOMP** → rules added on top that give messages addresses.
- **Protocol** → an agreed way to talk so both sides understand.
- **Pub/Sub** → one side shouts on a channel, anyone listening hears it (like radio).
- **Semantics** → just means "how it behaves / what it does."
- **Topic** → the named channel everyone tunes into.
- **Destination** → the address you send a message to.
- **Broker** → the post office that delivers messages to subscribers.
- **Relay server** → a middleman that passes messages between phone and PC.
- **P2P** → the two devices talk directly, no middleman.
- **NAT / STUN / TURN** → the hard tricks to make P2P work (you skipped these).
- **Payload** → the actual data inside the message (the letter in the envelope).
- **Serialization / JSON** → turning data into text to send it, then back again.
- **Fan-out** → one message copied to many receivers.

### Speed / size
- **Latency** → delay; how long until you see the result.
- **End-to-end latency** → the total delay across the whole path.
- **Round-trip** → there and back again.
- **Bandwidth** → how much data per second (the volume).
- **Bandwidth vs latency** → bandwidth = how much; latency = how fast. Different things.
- **Buffer** → a waiting area for data; too small and big stuff gets rejected.
- **Thread pool** → many workers doing tasks at once instead of one.
- **Bottleneck** → the one slow part that holds everything up.

### Streaming / image
- **Frame** → one single screenshot in the stream.
- **FPS** → how many frames you send each second.
- **Frame skipping** → dropping some frames to stay fast / not pile up.
- **JPEG** → small image file, slightly blurry — good for streaming.
- **PNG** → perfect-quality image but big — used only for OCR.
- **Lossy / lossless** → lossy throws away tiny detail to shrink; lossless keeps it all.
- **Compression / quality** → squeezing the image; lower quality = smaller file.
- **Adaptive** → automatically adjusts itself to conditions.
- **Delta encoding** → only send what changed (future idea, not built).
- **Keyframe** → a full fresh frame sent now and then as a reference.

### Flutter / UI
- **Aspect ratio** → the shape (width:height) of a screen, like 16:9.
- **BoxFit.contain** → fit the whole image inside, no cropping (leaves bars).
- **Letterbox / pillarbox** → the black bars (top/bottom or left/right).
- **Normalized coordinates** → using 0–1 (like "halfway") instead of pixels.
- **Callback** → a function that runs later, when something finishes.
- **Async / await** → wait for slow stuff without freezing the app.

### AI
- **OCR** → reading text out of a picture.
- **On-device** → the AI runs on the phone, not the cloud.
- **ML Kit** → Google's on-device AI library (does your OCR).
- **STT (Speech-to-Text)** → turning spoken words into text.
- **Native engine** → the phone's own built-in feature (no Azure needed).

### Scaling / security
- **Horizontal scaling** → handle more users by adding more servers.
- **Load balancer** → splits traffic across servers evenly.
- **Sticky sessions** → keep a user on the same server the whole time.
- **Stateful** → server remembers your ongoing connection.
- **Stateless** → each request stands alone, nothing remembered.
- **TLS / wss** → encrypted, secure connection (like https).
- **Authentication** → proving who you are.
- **Rate limiting** → capping attempts so no one can brute-force the PIN.

### General
- **Gyroscope** → phone sensor that senses tilt (used for the air-mouse).
- **pyautogui** → Python tool that moves the mouse and types on the PC.
- **mss** → Python tool that grabs fast screenshots.
- **Magic number** → a hardcoded value with no reason (the old 1.16).
