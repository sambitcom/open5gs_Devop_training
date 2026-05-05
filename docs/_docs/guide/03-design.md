---
title: High Level Design
---

## 1. Purpose

This document gives a high level design view of this Open5GS project tree. The goal is to help developers and DevOps engineers understand how the source code, runtime configuration, Web UI, packaging, and tests fit together before making changes or deploying a lab core.

Open5GS is a C-language implementation of EPC and 5G Core network functions. In this repository, the core network functions are built as separate daemons, share common protocol/runtime libraries, and are configured through YAML templates installed under the Open5GS configuration directory.

## 2. System Context

Open5GS sits between radio access networks, subscriber data, policy/session control, and packet data networks.

### Overall System Diagram

```text
                                      +----------------------+
                                      |   Operator / Admin   |
                                      +----------+-----------+
                                                 |
                                                 | HTTPS / HTTP :9999
                                                 v
                                      +----------------------+
                                      |      Open5GS Web UI  |
                                      | Express + Next.js    |
                                      +----------+-----------+
                                                 |
                                                 | MongoDB driver
                                                 v
        +------------------+          +----------------------+          +------------------+
        |       UE         |          |       MongoDB        |          | External Data    |
        | SIM / USIM       |          | subscribers, profiles|          | Network / IMS    |
        +--------+---------+          | accounts, sessions   |          | Internet / APN   |
                 |                    +----------+-----------+          +---------+--------+
                 | Radio                         ^                                ^
                 v                               |                                |
        +------------------+                     |                                |
        | eNB / gNB / RAN  |                     |                                |
        +--------+---------+                     |                                |
                 |                               |                                |
                 | S1AP or NGAP over SCTP        | DBI                            | IP packets
                 v                               |                                |
        +------------------+          +----------+-----------+          +---------+--------+
        | Access Control   |          | Subscriber / Policy  |          | User Plane       |
        | MME or AMF       +----------> HSS, UDR, UDM, AUSF, |          | SGW-U / UPF      |
        +--------+---------+          | PCF, PCRF, NSSF      |          +---------+--------+
                 |                    +----------+-----------+                    ^
                 | Control plane                 ^                                |
                 | GTP-C, PFCP, SBI, Diameter    | SBI / Diameter                 | GTP-U / PFCP
                 v                               |                                |
        +------------------+                     |                                |
        | Session Control  +---------------------+--------------------------------+
        | SGW-C / SMF      |
        +------------------+
```

At a high level:

* UE devices attach through an eNB for LTE/EPC or a gNB for 5G SA.
* RAN nodes connect to the control plane using S1AP for LTE or NGAP for 5G.
* Control plane functions authenticate subscribers, manage mobility, select slices, create sessions, and control user plane forwarding.
* User plane functions forward UE traffic through GTP-U and TUN interfaces toward external data networks.
* MongoDB stores subscriber and Web UI data.
* The Web UI provides a browser-based way to manage subscribers, profiles, and accounts.

## 3. Major Repository Areas

| Area | Purpose |
| --- | --- |
| `src/` | Network function daemon implementations such as AMF, SMF, UPF, MME, HSS, NRF, SCP, and SEPP. |
| `lib/` | Shared libraries for core runtime, protocol encoding/decoding, SBI, NAS, NGAP, S1AP, GTP, PFCP, Diameter, metrics, database access, cryptography, SCTP, TUN, and platform helpers. |
| `configs/` | Installable YAML templates, freeDiameter templates, systemd units, log rotation, examples, TLS assets, and platform service configuration. |
| `webui/` | Node.js, Express, Next.js, React, Redux, Mongoose, and Passport based Web UI. |
| `docs/` | Jekyll documentation site, guides, tutorials, troubleshooting notes, assets, and generated documentation content. |
| `docker/` | Dockerfiles and compose definitions for build, runtime, development, test, Web UI, and MongoDB services. |
| `vagrant/` | Vagrant environments for supported development platforms. |
| `debian/` | Debian packaging metadata and package install manifests. |
| `tests/` | Meson-driven unit, protocol, attach, registration, handover, VoLTE, CSFB, slicing, non-3GPP, transfer, crypto, SCTP, and fuzzing test code. |
| `scripts/` and `misc/` | Supporting scripts and miscellaneous installed runtime assets. |

## 4. Core Network Functions

The project builds each network function as an independent executable from `src/*/meson.build`.

| Function | Binary | Primary Role |
| --- | --- | --- |
| AMF | `open5gs-amfd` | 5G access and mobility management, NGAP endpoint for gNBs, NAS mobility control. |
| SMF | `open5gs-smfd` | 5G session management, PFCP control of UPF, IP session allocation, GTP-C support for EPC interworking paths. |
| UPF | `open5gs-upfd` | User plane forwarding, PFCP server, GTP-U endpoint, TUN interface integration. |
| NRF | `open5gs-nrfd` | 5G NF registration, discovery, and repository services. |
| SCP | `open5gs-scpd` | 5G service communication proxy for indirect SBI routing. |
| SEPP | `open5gs-seppd` | 5G roaming edge security and inter-PLMN service exposure. |
| AUSF | `open5gs-ausfd` | 5G authentication server function. |
| UDM | `open5gs-udmd` | 5G subscriber data front end and authentication data access. |
| UDR | `open5gs-udrd` | 5G subscriber data repository access. |
| PCF | `open5gs-pcfd` | 5G policy control. |
| NSSF | `open5gs-nssfd` | 5G network slice selection. |
| BSF | `open5gs-bsfd` | Binding support function. |
| MME | `open5gs-mmed` | LTE/EPC mobility, attach, bearer, paging, and S1AP/NAS control. |
| HSS | `open5gs-hssd` | LTE/EPC subscriber database and Diameter authentication data. |
| SGW-C | `open5gs-sgwcd` | Serving gateway control plane. |
| SGW-U | `open5gs-sgwud` | Serving gateway user plane. |
| PCRF | `open5gs-pcrfd` | EPC policy and charging rules function. |

## 5. Shared Library Design

The source daemons are intentionally thin around reusable libraries. Important shared layers include:

* `lib/core`: event loop, timers, queues, pools, logging, memory, sockets, FSM helpers, and common primitives.
* `lib/app`: process startup, configuration loading, application lifecycle, and common daemon behavior.
* `lib/dbi`: MongoDB/database integration used by subscriber data paths.
* `lib/sbi`: HTTP/2 service based interface support, OpenAPI-generated models, NF profile handling, discovery, and client/server helpers.
* `lib/nas`, `lib/ngap`, `lib/s1ap`: 5G and EPS access signaling protocols.
* `lib/gtp` and `lib/pfcp`: tunnel/session control protocols used between control and user plane functions.
* `lib/diameter`: Diameter interfaces for EPC and IMS/VoLTE related integrations.
* `lib/metrics`: Prometheus and no-op metrics backends.
* `lib/tun`, `lib/ipfw`, `lib/sctp`, `lib/crypt`: platform networking, SCTP transport, and crypto support.

This layout keeps protocol parsing and reusable infrastructure in one place while each daemon owns its network-function-specific state machines and handlers.

## 6. Runtime Configuration

Runtime behavior is driven by YAML configuration templates in `configs/open5gs/*.yaml.in`. Meson installs these templates with paths expanded for the target system.

Common configuration sections include:

* `logger`: log file path and log level.
* `global.max`: resource limits such as UE and peer counts.
* `sbi`: HTTP service based interface server and client endpoints for 5G core functions.
* `ngap`, `s1ap`, `gtpc`, `gtpu`, `pfcp`, `diameter`: protocol-specific bind addresses and peer configuration.
* `metrics`: Prometheus metrics listener addresses.
* `session`: UE address pools, gateways, DNN/APN bindings, and TUN device choices.
* `freeDiameter`: Diameter configuration file location for EPC and IMS paths.

For 5G SA, functions can discover each other through NRF directly or through SCP depending on the `sbi.client` configuration. For EPC, functions rely more heavily on statically configured Diameter, GTP-C, and PFCP peers.

## 7. Control Plane and User Plane Flow

### 5G SA

```text
                         5G SA Control Plane and User Plane

      +-----+        Radio        +-----+       NGAP/SCTP       +-----+
      | UE  +-------------------->+ gNB +---------------------->+ AMF |
      +-----+                     +-----+                       +-+-+-+
                                                                  | |
                                                                  | | SBI
                                                                  | v
                 +---------+     SBI      +-----+      SBI      +-+-+--+
                 | AUSF    +<------------>+ NRF +<------------->+ SCP  |
                 +----+----+              +--+--+               +--+---+
                      |                      ^                     ^
                      | SBI                  | SBI discovery        | SBI routing
                      v                      |                     |
                 +----+----+     SBI      +--+--+      SBI      +--+---+
                 | UDM     +<------------>+ UDR +<------------->+ PCF  |
                 +---------+              +-----+               +------+

                                      SBI
                    +---------------------------------------------+
                    |                                             v
                  +-+-+             PFCP                   +------+------+
                  |SMF+------------------------------------>+    UPF      |
                  +-+-+                                     +------+------+
                    ^                                              |
                    | N1/N2 session control                         | GTP-U / TUN
                    +-----------------------------------------------v
                                                            +--------------+
                                                            | Data Network |
                                                            +--------------+
```

1. gNB connects to AMF over NGAP/SCTP.
2. AMF handles NAS registration and mobility management.
3. AMF uses SBI to reach AUSF, UDM, UDR, PCF, NSSF, NRF, SCP, and SMF as needed.
4. SMF creates and manages PDU sessions.
5. SMF controls UPF through PFCP.
6. UPF forwards UE traffic over GTP-U and local TUN interfaces.

### LTE/EPC

```text
                         LTE/EPC Control Plane and User Plane

      +-----+        Radio        +-----+       S1AP/SCTP       +-----+
      | UE  +-------------------->+ eNB +---------------------->+ MME |
      +-----+                     +-+---+                       +-+-+-+
                                    |                             | |
                                    |                             | | Diameter S6a
                                    | S1-U / GTP-U                | v
                                    |                           +-+-+--+
                                    |                           | HSS  |
                                    |                           +------+
                                    |
                                    v
                               +----+-----+        GTP-C        +-------+
                               |  SGW-U   |<------------------->+ SGW-C |
                               +----+-----+                     +---+---+
                                    |                               |
                                    | GTP-U                         | GTP-C
                                    v                               v
                               +----+-----+        PFCP/GTP-C   +---+---+
                               | UPF/PGW-U|<------------------->+ SMF/  |
                               +----+-----+                     | PGW-C |
                                    |                           +---+---+
                                    |                               |
                                    v                               | Diameter Gx/Rx
                              +-----+------+                        v
                              | Data/IMS   |                    +---+---+
                              | Network    |                    | PCRF  |
                              +------------+                    +-------+
```

1. eNB connects to MME over S1AP/SCTP.
2. MME handles attach, authentication, mobility, paging, and bearer control.
3. HSS provides subscriber and authentication data over Diameter.
4. SGW-C and SMF/PGW-C manage gateway control plane state.
5. SGW-U and UPF/PGW-U carry user traffic over GTP-U.
6. PCRF provides policy and charging rules over Diameter interfaces.

## 8. Web UI Design

The `webui/` application is a separate Node.js service that defaults to port `9999`.

```text
                         Web UI and Subscriber Data Path

       +------------------+       HTTP :9999       +-----------------------+
       | Browser / Admin  +----------------------->+ Express Server        |
       +------------------+                        | webui/server/index.js |
                                                   +-----------+-----------+
                                                               |
                              +--------------------------------+----------------+
                              |                                                 |
                              v                                                 v
                     +------------------+                              +------------------+
                     | Next.js / React  |                              | /api routes      |
                     | pages + UI       |                              | auth + db        |
                     +------------------+                              +--------+---------+
                                                                                |
                                                                                | Mongoose
                                                                                v
                                                                       +--------+---------+
                                                                       | MongoDB          |
                                                                       | Subscriber       |
                                                                       | Profile          |
                                                                       | Account          |
                                                                       | Session store    |
                                                                       +------------------+
```

Server-side responsibilities:

* Express hosts API routes and hands page rendering to Next.js.
* Mongoose connects to MongoDB using `DB_URI`, defaulting to `mongodb://127.0.0.1/open5gs`.
* Passport provides local login and JWT-protected API access.
* `express-restify-mongoose` exposes REST resources for subscribers, profiles, and accounts.
* Sessions are stored in MongoDB with `connect-mongo`.

Client-side responsibilities:

* Next.js and React render the browser UI.
* Redux and Redux Saga manage client state and asynchronous CRUD flows.
* Components under `webui/src/components` and containers under `webui/src/containers` implement the subscriber, profile, account, authentication, layout, sidebar, and notification screens.

MongoDB is therefore both a subscriber data store for Open5GS and the backing store for Web UI accounts and sessions.

## 9. Build, Packaging, and Deployment

The native build uses Meson from the top-level `meson.build`. The build includes:

```text
                         Build and Deployment View

      +---------------------+
      | Source Repository   |
      | src, lib, configs   |
      +----------+----------+
                 |
                 | meson setup / compile / install
                 v
      +---------------------+       installs       +----------------------+
      | Build Artifacts     +--------------------->+ Runtime Host/VM      |
      | open5gs-* daemons   |                      | systemd services     |
      +----------+----------+                      +----------+-----------+
                 |                                            |
                 | package                                    | reads
                 v                                            v
      +---------------------+                      +----------------------+
      | Debian Packages     |                      | /etc/open5gs/*.yaml  |
      | per NF install      |                      | /etc/freeDiameter    |
      +---------------------+                      +----------------------+

      +---------------------+      compose up      +----------------------+
      | docker/             +--------------------->+ MongoDB + Web UI     |
      | Dockerfiles         |                      | build/run/test/dev   |
      | docker-compose.yml  |                      | containers           |
      +---------------------+                      +----------------------+
```

* `configs`: installable runtime configuration.
* `lib`: shared protocol/runtime libraries.
* `src`: daemon executables.
* `misc`: supporting runtime files.
* `tests`: enabled when tests can run natively or through an executable wrapper.
* `tests/fuzzing`: enabled through the Meson fuzzing option.

Deployment support is split across:

* `configs/systemd`: systemd service templates for each daemon.
* `debian`: Debian package metadata and per-function install manifests.
* `docker`: Compose services for MongoDB, Web UI, build, run, test, and dev environments.
* `vagrant`: platform-specific VM workflows.

The Docker Compose stack includes MongoDB, Web UI, build images, a runtime container, a test container that runs `meson test -v`, and a development container with TUN access.

## 10. Testing Strategy

Tests are organized by domain under `tests/` and wired through Meson. The suite covers:

* core runtime primitives and utilities,
* cryptography,
* SCTP,
* protocol message encoding/decoding,
* 4G attach and 5G registration,
* VoLTE and VoNR,
* CSFB,
* slicing,
* handover,
* non-3GPP access,
* UE context transfer,
* application-function behavior,
* fuzzing for selected protocol messages.

The test layout mirrors the architecture: low-level libraries are tested independently, while attach/registration/session tests exercise cross-function behavior through common test helpers.

## 11. Observability and Operations

Operational support is built into the core project structure:

* Each daemon writes its own log file through the `logger.file.path` configuration.
* Prometheus metrics listeners are configured per network function where supported.
* systemd units provide process supervision on Linux hosts.
* logrotate and newsyslog templates support log retention.
* Docker test and dev environments include NET_ADMIN capability and `/dev/net/tun` access for user plane testing.

## 12. Extension Points

Common places to extend the project are:

* Add or change network-function behavior in the relevant `src/<nf>/` directory.
* Add reusable protocol/runtime logic in `lib/` when more than one daemon needs it.
* Add YAML options in `configs/open5gs/*.yaml.in` and wire them through the daemon context parser.
* Add Web UI data or screens through `webui/server/models`, `webui/server/routes`, `webui/src/modules`, `webui/src/components`, and `webui/src/containers`.
* Add tests under the matching `tests/<domain>/` directory and register them in Meson.
* Add deployment behavior in `configs/systemd`, `debian`, or `docker` depending on the target runtime.

## 13. Design Principles

* Keep each network function independently deployable.
* Share protocol and runtime infrastructure through `lib/` instead of duplicating it in daemons.
* Keep runtime behavior explicit in YAML configuration.
* Prefer standards-based interfaces: SBI, NGAP, S1AP, NAS, GTP, PFCP, Diameter, SCTP, and Prometheus.
* Preserve control/user plane separation so deployments can scale or place UPF/SGW-U independently from control plane functions.
* Keep tests close to the feature or protocol domain they validate.
