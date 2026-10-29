# Dockerized Dev Environment (devops branch)

This project configures a dockerized development environment for devops usage. The `devops` branch contains a more specific build with additional functionality for Terraform, OpenTofu, GCP, AWS and running Docker from within the container for use with aws `ECR`. There are several advatanges to developing in these containers over traditional host-based development environments. Especially when combined with VSCode Dev Containers, it's integrated debugger, and Remote Development. These advantages include:

* **Isolation**: Installed software and modified resources are contained within the Docker container.
    * Egress filtering can be applied to the container using the host firewall
    * Drivers exist for docker which can further isolate the container (`IPVlan`, `MacVLAN`, etc)
* **Consistency**: The Docker environment remains consistent across different machines and operating systems.
    * All devs write and test code using the same runtime stack and OS
    * Production can run from the same container
* **Security**: The container environment can be provisioned within the context of organizational security goals.
    * Easily scan, test and distribute vulnerability mitigations.
    * Change management is simpler as tracking relates to a single environment
* **Reproducibility**: Easily reproduce the environment using the docker configuration and Makefile.
* **Ease of Setup**: Set up the environment once and share the configuration with everyone.
* **Dependency Management**: Applications running in Docker have all necessary software provisioned for their functionality.
* **VCS Integration**: The entire environment can be versioned in git for change tracking and collaboration.
* **Workstation Stability**: Software installed in the Docker container does not impact the host operating system.
* **Elevated Access**: Docker provides an alternative for obtaining elevated access on a host system for managing software.
    * easily experiment with new versions or stack dependencies

The `devops` branch contains additional `make` targets, Python libraries and additional utilities to support DevOps workflows.

Among the targets, a `rundock` target will volume mount `/var/run/docker.sock` in the container and provide R/W access to it via the docker entrypoint. The Docker entrypoint adds supplementary group permissions to the user running the container so files volume mounted in the container "just work" without sudo shenanigans.

The `rundock` target is an elevated security risk. Since the user running the container (or any process they start) now has access to any container running on the system, and potentially root access to the host operating system itself. This isn't intended for production use and is rather intended as temporary elevation on a single-user development system to allow for automating workflows involving docker containers. Other security controls such as docker socket proxies exist which allow for further restricting access on the docker socket but this does raise the complexity bar somewhat and also brings another layer of management into the fold. The impact of the technical cost and risk decisions need to be carefully considered.

## Usage
Obviously, `docker` and it's related support software needs to be installed on the host system. Additionally, the `make` utility is used to assist in managing the build environment, but isn't necessary. You could enter the build commands manually of course.

A volume mount "app" directory is enabled at docker runtime. This enables a location on the host system to be used as a shared directory inside the running Docker container. Any development file can be written to this location for persistence when the container is not running.

A persistent home directory residing as a subdirectory in the runtime user's home directory (`~/.devdocker-home`) is volume mounted to `/home/$USER` inside the container to preserve shell history, configuration files, and state between container runs.

If `SSH_AUTH_SOCK` is set in the host environment, the Makefile automatically forwards the host SSH agent socket and environment variable into the interactive container session. If `SSH_AUTH_SOCK` is unset on the host, a warning displays instructing manual mounting of `~/.ssh` or initialization of `ssh-agent`.

## Permissions

If the app directory is created by the user running the docker build, it will be writable by the user in the container, as well as user on the host system. If you run into odd permission issues for some reason, you may need to experiment with the permissions.

Of note, if using volume mounts, the `docker` daemon will create the directories on the host system with root ownership. This isn't ideal, so the Makefile attempts to create these as the user running `make` at build/run time.

Docker may not allow you to `sudo` within the container, failing with the error message below. If this is the case, check that the docker filesystem (`/var/lib/docker` on debian/ubuntu) on the host is mounted without the `nosuid` option. Having this mount option may cause the error message below. I remedied this by creating a separate LVM volume for docker on my docker host and mounting it on `/var/lib/docker` without the `nosuid` option. The `nosuid` option prevents programs on a filesystem from being set with a filesystem flag to allow them to execute with root privilege when run. It's best practice to leave this option intact, especially for a directory like `/var` where many different processes are allowed to write files.  Opening up only the `/var/lib/docker` directory provides usability with reduced risk to everything under the `/var` directory.
   ``` bash
   docker sudo: effective uid is not 0, is /usr/bin/sudo on a file system with the 'nosuid' option set or an NFS file system without root privilege
   ```

Be aware of the security issues with the `rundock` Make target which mounts the host `docker.socket` in the container as a volume mount. This was implemented to allow docker integration (eg:`docker login`) in the container for pushing images to AWS ECR. For this functionality to work, the user in the container must be able to read/write the volume mounted `docker.socket` on the host system.

Allowing access to `docker.socket` has the potential to not only interfere with any running container on the host, but compromise the entire host system. There is a project named [Docker Socket Proxy](https://github.com/Tecnativa/docker-socket-proxy) which attempts to minimize this attack surface but running any sort of un-trusted environment with a mounted `docker.socket` is a stupendously bad idea.

## Customization

### etc/bashrc-addition

The file `etc/bashrc-addition` is added to the `/etc/bash.bashrc` Docker container during build. Customize this file with specific aliases, functions, or other shell shortcuts.

### requirements.txt

The `requirements.txt` file contains Python dependency packages to install into the Docker container. Other languages and dependency conventions could certainly be implemented instead.
## Dockerfile

The Dockerfile sets up a lightweight Python development environment based on the official `python:3.15.2-slim` image. The environment includes a non-root user for development use and sudo access for elevating to install software or other management needs.

- Creates a non-root user with `/bin/bash` as the default shell using the UID and GID of the user running the build.
- Grants sudo access to the user.
- Copies custom additions to `bash.bashrc` into the image.
- Sets the working directory to `/apps`.
- Installs Python dependencies listed in `requirements.txt` using pip.
- Updates and upgrades system packages.
- Installs core development tools, cloud CLIs (AWS, GCP), OpenTofu, Terraform, Go, and 1Password CLI.
- Adds the user to the sudoers group with passwordless sudo access.
- Appends custom bash code from `/tmp/bashrc-addition` to `/etc/bash.bashrc`.
- Sets the default entrypoint to `/usr/local/bin/entrypoint.sh` with `/bin/bash` as default command.

## Makefile

A Makefile manages the build and run process. This provides simple commands for building, running, and cleaning up the Docker containers and images.

For more insight into the docker build proceses, you can export `DEBUG=1` or declare it along with the build command
```bash
DEBUG=1 make build|rebuild
```

### Makefile Usage

1. **Build Docker Image:**

    ```bash
    make build
    ```

    This command builds a Docker image named `devops-image` with the latest tag.

2. **Run Docker Container:**

    ```bash
    make run
    ```

    This command runs a Docker container named `devops-container` with mounted `./apps` directory and persistent home directory (`~/.devdocker-home`). Automatically forwards `SSH_AUTH_SOCK` if set on the host.

3. **Run Docker Container with Docker Socket:**

    ```bash
    make rundock
    ```

    Runs a Docker container with mounted `./apps` directory, persistent home directory (`~/.devdocker-home`), and mounted host Docker socket. Automatically forwards `SSH_AUTH_SOCK` if set on the host.

4. **Show Variables:**

    ```bash
    make show-variables
    ```

    This command echoes the values of various environment variables used in the Makefile.

5. **Generate .env File:**

    ```bash
    make env
    ```

    This command generates a `.env` file with the environment variables used in the Makefile for use with docker-compose.

6. **Stop Docker Container:**

    ```bash
    make stop
    ```

    This command stops the running Docker container named `devops-container`.

7. **Clean Up:**

    ```bash
    make clean
    ```

    This command removes the Docker container (`devops-container`) and the Docker image (`devops-image`).

8. **Connect to running container:**

    ```bash
    make connect
    ```

    This command connects to the running Docker container (`devops-container`).

9. **Upgrade via pip when building:**

    ```bash
    make build_upgrade
    ```

    This command instructs pip to upgrade the packages found in `requirements.txt` to their latest version when building the Docker container.

10. **Build using the --no-cache options:**

    ```bash
    make rebuild
    ```

    This command instructs docker to build the image without using the Docker build cache. Can be useful for troubleshooting to ensure a consistent build when other things are questionable.

### Variables

- `PROJECT`: Name of the project used to derive image and container names (default: devops).
- `IMAGE_NAME`: Name of the Docker image (default: devops-image).
- `IMAGE_VERSION`: Version tag of the Docker image (default: latest).
- `CONTAINER_NAME`: Name of the Docker container (default: devops-container).
- `HOST_PATH`: Path on the host machine for volume mounting (default: ./apps).
- `CONT_APP_MNT`: Mount point path inside the container (default: /apps).
- `PERSIST_HOME`: Path on the host machine for persistent user home directory (default: ~/.devdocker-home).

### Notes

- Adjust the `HOST_PATH` variable in the Makefile according to your project structure.
- The provided Makefile assumes that you have Docker installed on your machine.

### Makefile Commands

- `build`: Build the Docker image.
- `build_upgrade`: Instruct pip to install/upgrade packages in requirements.txt.
- `clean`: Remove the Docker container and image.
- `connect`: Connect to the running Docker container.
- `env` : Create a .env file for use with docker compose
- `help`: View the make targets
- `run`: Run the Docker container with mounted `./apps`, persistent home (`~/.devdocker-home`), and optional `SSH_AUTH_SOCK` forwarding.
- `rundock`: Run the Docker container with mounted `./apps`, persistent home (`~/.devdocker-home`), mounted host Docker socket, and optional `SSH_AUTH_SOCK` forwarding.
- `rebuild`: Build the docker image using `--no-cache`
- `stop`: Stop the running Docker container.

```bash
# Example usage:
#   make build
#   make run
#   make rundock
#   make stop
#   make clean
#   make connect
#   make build_upgrade
#   make rebuild
```