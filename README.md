

# Dockerized Dev Environment TEST
This is an experiment to see how well a dockerized development environment might work. The benefits to this:
 * **Isolated** - any installed software, or modified resources, are largely limited to the container. 
 * **Consistency** - The Docker environment is consistent on any machine or OS underlying it
 * **Reproducibility** - Reproducing the environment only needs a text file 
 * **Ease of Setup** - Everything needed to setup the environment can be done once and used by everyone
 * **Dependency Management** - Applications running in Docker have software fully provisioned for what they need to function
 * **VCS Integration** - The entire environment can be versioned in git for change tracking and collaboration
 * **Workstation Stability** - Software installed in the Docker container does not affect the host operating system, or it's installed software
 * **Elevated Access** - Docker provides a viable alternative for obtaining elevated access on a host system for installing application support software.

This project makes use of a volume mount "app" directory. This allows for running full capabilities of an IDE on the host system, and writing to a shared location inside the running docker container. The application can then be run from inside the docker container where all of the support software is installed. Two sample files are included in the app directory.

The app directory has 0777 permissions applied to it so it can be shared with the `tux` user inside the container. The Unix UID and GID of the `tux` user could be fiddled with to make them the same as the developer and allow for tighter permissions.

## etc/bashrc-addition
The file etc/bashrc-addition is added to the /etc/bash.bashrc Docker container during build. If you have specific aliases, functions or other shell shortcuts you like to use, put them in that file.

## requirements.txt
The file requirements.txt contains the Python dependency packages to install into the Docker container. 

The Dockerfile sets up a lightweight Python development environment based on the official Ubuntu 3.8-slim-buster image. The environment includes a non-root user named `tux` for development use, and sudo access for elevating to install software or other management needs.

## Dockerfile

- Creates a non-root user (`tux`) with `/bin/bash` as the default shell.
- Grants sudo access to the `tux` user.
- Copies custom additions to `bash.bashrc` into the image.
- Sets the working directory to `/app`.
- Installs Python dependencies listed in `requirements.txt` using pip3.
- Updates and upgrades the system packages.
- Installs support packages such as sudo, net-tools, vim, nano, zsh, and git.
- Adds the `tux` user to the sudoers group with passwordless sudo access.
- Appends custom bash code from `/tmp/bashrc-addition` to `/etc/bash.bashrc`.
- Switches to the non-root user `tux` for the container shell.
- Specifies the default command to run when the container starts as `/bin/bash`.


A Makefile manages the build and run process. This provides simple commands for building, running, and cleaning up the Docker containers and images.

## Makefile Usage

1. **Build Docker Image:**

    ```bash
    make build
    ```

    This command builds a Docker image named `aws-image`.

2. **Run Docker Container:**

    ```bash
    make run
    ```

    This command runs a Docker container named `aws-tester` based on the `aws-image`.

3. **Run Docker Container with Volume Mount:**

    ```bash
    make runm
    ```

    This command runs a Docker container with volume mounting, allowing you to mount the `./app` directory from the host to `/app/` in the container. It opens a bash shell in the container.

4. **Stop Docker Container:**

    ```bash
    make stop
    ```

    This command stops the running Docker container named `aws-tester`.

5. **Clean Up:**

    ```bash
    make clean
    ```

    This command removes the Docker container (`aws-tester`) and the Docker image (`aws-image`).

## Variables

- `IMAGE_NAME`: Name of the Docker image (default: aws-image).
- `CONTAINER_NAME`: Name of the Docker container (default: aws-tester).
- `HOST_PATH`: Path on the host machine for volume mounting (default: ./app).

## Notes

- Make sure to adjust the `HOST_PATH` variable in the Makefile according to your project structure.

- The provided Makefile assumes that you have Docker installed on your machine.

## Makefile Commands

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