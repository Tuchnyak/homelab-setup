# Project Context: Multi-Purpose Home Server Setup

## 1. Core Objective
The primary goal is to create a comprehensive, step-by-step guide (`homelab-setup-plan.md`) for setting up a multi-purpose home server on a dedicated machine. The user, a Java/Kotlin developer, will use this guide for initial setup and future reference.

## 2. User Profile & Goals
- **Primary Role:** Backend Developer (Java/Kotlin).
- **Secondary Role:** Aspiring Linux System Administrator (learning-by-doing).
- **Primary Motivations:**
    - Create a stable platform for self-hosting various services.
    - Establish a sandboxed environment for software development and deployment practice.
    - Gain practical experience in Linux server administration, containerization, and networking.
    - Build a passive income source from future projects hosted on this server.
- **Key Use Cases:**
    - **Development Sandbox:** Deploying and testing custom Java/Kotlin applications.
    - **Media Server:** Streaming local media to family devices (e.g., TV).
    - **Private Cloud:** File storage and synchronization (Nextcloud).
    - **File Synchronization:** Cross-device sync (Syncthing).
    - **Automated Downloads:** Torrent client for media acquisition.
    - **Future Exploration:** Experimenting with local LLMs.

## 3. Hardware Specifications
- **CPU:** AMD Ryzen 5 3500U (4 cores)
- **GPU:** Integrated Radeon Vega 8 Graphics
- **RAM:** 16 GB DDR4
- **Storage:** 1 TB PCIe3 NVMe SSD

*Constraint Implication:* The 16GB RAM is a significant constraint, especially for running multiple services plus experimental LLMs. This constraint heavily influenced the choice of a lightweight, container-based architecture.

## 4. Key Architectural Decisions & Rationale

### 4.1. Operating System: Ubuntu Server LTS with Btrfs
- **Rationale:** Stability, extensive community support, vast documentation, and industry prevalence. LTS (Long-Term Support) ensures a stable base with security updates for years. The choice of **Btrfs** as the filesystem enables advanced features like **snapshots** for easy system rollbacks and improved **data integrity** through checksums, which is crucial for a home server.

### 4.2. Virtualization/Containerization: Podman & Podman-Compose
- **Decision:** Use Podman instead of the more common Docker.
- **Rationale:**
    - **Security:** Podman's default rootless mode enhances security by not requiring a central daemon running as root.
    - **System Integration:** Better, native integration with Linux systemd for managing container lifecycle (e.g., auto-start on boot).
    - **Compatibility:** CLI commands are aliased to be nearly identical to Docker, easing the transition and leveraging existing knowledge. `podman-compose` provides a direct equivalent to `docker-compose`.

### 4.3. Service Architecture: Hybrid (Bare-metal + Containers)
- **Decision:** Install a minimal OS on bare metal and run all applications/services within containers.
- **Rationale:**
    - **Isolation:** Prevents dependency conflicts between services (e.g., different services needing different versions of Python or a database).
    - **Reproducibility & Portability:** Containerized setups are easy to back up, move, and redeploy.
    - **Cleanliness:** The host OS remains clean and uncluttered, only containing the containerization engine (Podman).

### 4.4. Networking: Nginx Proxy Manager with HTTPS
- **Decision:** Use a dedicated reverse proxy container to manage ingress traffic and secure it with HTTPS.
- **Rationale:**
    - **Centralized Access:** Provides a single entry point to all services.
    - **Simplified UX:** Enables access to services via user-friendly hostnames (e.g., `https://jellyfin.lan`) instead of IP:port combinations.
    - **Abstraction:** Hides the internal port mapping of services.
    - **Security (HTTPS/SSL):** Encrypts all traffic between clients and services, protecting sensitive data and ensuring data integrity. Nginx Proxy Manager automates the acquisition and renewal of SSL certificates (e.g., via Let's Encrypt DNS Challenge).
    - **Ease of Management:** Provides a web UI to manage proxy rules and SSL certificates, simplifying a traditionally complex task.

### 4.5. Data Persistence Strategy: Centralized `/srv` Directory
- **Decision:** All persistent container data will be stored on the host filesystem under `/srv`, using volume mounts.
- **Rationale:**
    - **Data Safety:** Decouples service data from the ephemeral container lifecycle. Containers can be destroyed and recreated without data loss.
    - **Simplified Backups:** The entire state of all services' data can be backed up by archiving a single directory (`/srv`).
    - **Clarity & Organization:** Provides a single, logical location for all important user and application data.

### 4.6. Application Deployment Workflow: Kamal for Custom Projects
- **Decision:** Use `podman-compose` for third-party infrastructure services (Jellyfin, Nextcloud) and `Kamal` for the user's own Java/Kotlin applications.
- **Rationale:**
    - **Separation of Concerns:** Distinguishes between setting up "infrastructure" and deploying "applications".
    - **Developer Experience (DX):** Kamal provides a streamlined, professional workflow for developers. It automates the build-push-deploy cycle.
    - **Best Practices:** The Kamal workflow (build locally -> push to registry -> deploy on server) mirrors modern CI/CD practices, providing valuable experience. The server only ever runs final, pre-built artifacts, keeping it clean and secure.

### 4.7. File Sharing: Samba (SMB)
- **Decision:** Implement a Samba share for easy file access from desktop clients on the local network.
- **Rationale:** Provides a native, OS-level integration for file management (drag-and-drop files to/from the server) which is more convenient for large files than a web UI like Nextcloud. It's the de-facto standard for LAN file sharing.
