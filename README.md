# Homelab Setup Guide

This repository contains a comprehensive, step-by-step guide for setting up a multi-purpose home server (Homelab). The project's goal is to provide a detailed, actionable plan for deploying various services on a single physical or virtual machine.

## Repository Structure

- **`/release/`**: This directory holds the finalized, ready-for-publication versions of the manual in different languages.
- `homelab-setup-plan-current.md`: This is the main working document, currently under active development and editing. **It may contain raw and unstructured text.**
- `00_additional_context.md` and `01_spec.md`: These files provide additional context, specifications, and architectural decisions made during the planning phase.

## Key Technologies and Services Covered

The guide details the setup and configuration of:

- **Operating System:** Ubuntu Server LTS with Btrfs filesystem for robust data management.
- **Containerization:** Podman and Podman-Compose, emphasizing rootless and systemd-native integration as a secure Docker alternative.

