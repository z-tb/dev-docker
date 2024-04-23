# Dockerized Dev Environment

This project configures a dockerized development environment for AWS usage. The `devops` branch contains a more specific AWS build with additional functionality. There are several advatanges to developing in these containers over traditional host-based development environments. These advantages include:

* **Isolation**: Installed software and modified resources are contained within the Docker container.
    * Egress filtering can be applied to the container using the host firewall
    * Drivers exist for docker which can further isolate the container (`IPVlan`, `MacVLAN`, etc)
* **Consistency**: The Docker environment remains consistent across different machines and operating systems.
* **Reproducibility**: Easily reproduce the environment using the docker configuration and Makefile.
* **Ease of Setup**: Set up the environment once and share the configuration with everyone.
* **Dependency Management**: Applications running in Docker have all necessary software provisioned for their functionality.
* **VCS Integration**: The entire environment can be versioned in git for change tracking and collaboration.
* **Workstation Stability**: Software installed in the Docker container does not impact the host operating system.
* **Elevated Access**: Docker provides an alternative for obtaining elevated access on a host system.

## Usage
Obviously, `docker` and it's related support software needs to be installed on the host system. Additionally, the `make` utility is used to assist in managing the build environment, but isn't necessary. You could enter the build commands manually of course.

A volume mount "app" directory is enabled at docker runtime. This enables the full capabilities of an IDE on the host system while writing to a shared location inside the running Docker container. The application being developed is run within the container, where all supporting software is installed. Run `make runm` to volume mount the app directory within the container. Several other `make` targets exist for different functionaly such as running the container with permissions of the user launching docker instead of just `root`.

## Permissions

If the app directory is created by the user running the docker build, it should be writable by the user in the container as well as user on the host system. If you run into odd permission issues for some reason, you may need to experiment with the permissions.

Docker may not allow you to `sudo` within the container, failing with the error message below. If this is the case, check that the docker filesystem (`/var/lib/docker` on debian/ubuntu) on the host is mounted without the `nosuid` option. Having this mount option may cause the error message below. I remedied this by creating a separate LVM volume for docker on my docker host and mounting it on `/var/lib/docker` without the `nosuid` option. The `nosuid` option prevents programs on a filesystem from being set with a filesystem flag to allow them to execute with root privilege when run. It's best practice to leave this option intact, especially for a directory like `/var` where many different processes are allowed to write files.  Opening up only the `/var/lib/docker` directory provides usability with reduced risk to everything under the `/var` directory.
   ``` bash
   docker sudo: effective uid is not 0, is /usr/bin/sudo on a file system with the 'nosuid' option set or an NFS file system without root privilege
   ```

## Customization

### etc/bashrc-addition

The file `etc/bashrc-addition` is added to the `/etc/bash.bashrc` Docker container during build. Customize this file with specific aliases, functions, or other shell shortcuts.

### requirements.txt

The `requirements.txt` file contains Python dependency packages to install into the Docker container. Other languages and dependency conventions could certainly be implemented instead.
## Dockerfile

The Dockerfile sets up a lightweight Python development environment based on the official Ubuntu 3.8-slim-buster image. The environment includes a non-root user for development use and sudo access for elevating to install software or other management needs.

- Creates a non-root user with `/bin/bash` as the default shell using the UID and GID of the user running the build.
- Grants sudo access to the user.
- Copies custom additions to `bash.bashrc` into the image.
- Sets the working directory to `/app`.
- Installs Python dependencies listed in `requirements.txt` using pip3.
- Updates and upgrades the system packages.
- Installs support packages such as sudo, net-tools, vim, nano, zsh, and git.
- Adds the user to the sudoers group with passwordless sudo access.
- Appends custom bash code from `/tmp/bashrc-addition` to `/etc/bash.bashrc`.
- Switches to the non-root user for the container shell.
- Specifies the default command to run when the container starts as `/bin/bash`.

## Makefile

A Makefile manages the build and run process. This provides simple commands for building, running, and cleaning up the Docker containers and images.

### Makefile Usage

1. **Build Docker Image:**

    ```bash
    make build
    ```

    This command builds a Docker image named `dev-test-image` with the latest tag.

2. **Run Docker Container:**

    ```bash
    make run
    ```

    This command runs a Docker container named `dev-test-container` based on the `dev-test-image:latest`.

3. **Run Docker Container with Volume Mount:**

    ```bash
    make runm
    ```

    This command runs a Docker container with volume mounting, allowing you to mount the `./app` directory from the host to `/app/` in the container. It opens a bash shell in the container.

4. **Stop Docker Container:**

    ```bash
    make stop
    ```

    This command stops the running Docker container named `dev-test-container`.

5. **Clean Up:**

    ```bash
    make clean
    ```

    This command removes the Docker container (`dev-test-container`) and the Docker image (`dev-test-image`).

### Variables

- `IMAGE_NAME`: Name of the Docker image (default: dev-test-image).
- `IMAGE_VERSION`: Version tag of the Docker image (default: latest).
- `CONTAINER_NAME`: Name of the Docker container (default: dev-test-container).
- `HOST_PATH`: Path on the host machine for volume mounting (default: ./app).

### Notes

- Adjust the `HOST_PATH` variable in the Makefile according to your project structure.

- The provided Makefile assumes that you have Docker installed on your machine.

### Makefile Commands

- `build`: Build the Docker image.
- `run`: Run the Docker container.
- `runm`: Run the Docker container with volume mounting.
- `stop`: Stop the running Docker container.
- `clean`: Remove the Docker container and image.

```bash
# Example usage:
#   make build
#   make run
#   make runm
#   make stop
#   make clean
