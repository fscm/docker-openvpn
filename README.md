# OpenVPN for Docker

A small OpenVPN image that can be used to start an OpenVPN server.

## Supported tags

- `2.4.0`
- `2.4.7`
- `2.4.9`, `latest`

## What is OpenVPN?

> OpenVPN provides flexible VPN solutions to secure your data communications, whether it's for Internet privacy, remote access for employees, securing IoT, or for networking Cloud data centers.

*from* [openvpn.net](https://openvpn.net)

> OpenVPN is the name of the open source project started by our co-founder. OpenVPN protocol has emerged to establish itself as a de- facto standard in the open source networking space with over 50 million downloads. OpenVPN is entirely a community-supported OSS project which uses the GPL license. The project has many developers and contributors from OpenVPN Inc. and from the broader OpenVPN community. In addition, there are numerous projects that extend or are otherwise related to OpenVPN.

*from* [openvpn.net/community](https://openvpn.net/community/)

## Getting Started

There are a couple of things needed for the script to work.

### Prerequisites

Docker, either the Community Edition (CE) or Enterprise Edition (EE), needs to
be installed on your local computer.

#### Docker

Docker installation instructions can be found
[here](https://docs.docker.com/install/).

### Usage

In order to end up with a functional OpenVPN service - after having build
the container - some configurations have to be performed.

To help perform those configurations a small set of commands is included on the
Docker container.

- `help` - Usage help.
- `init` - Configure the OpenVPN service.
- `start` - Start the OpenVPN service.

To store the configuration settings of the OpenVPN server as well as the users
information a volume should be created and added to the container when running
the same.

#### Creating Volumes

To be able to make all of the OpenVPN data persistent, the same will have to
be stored on a different volume.

Creating volumes can be done using the `docker` tool. To create a volume use
the following command:

```
docker volume create --name VOLUME_NAME
```

Two create the required volume the following command can be used:

```
docker volume create --name my_openvpn
```

**Note:** A local folder can also be used instead of a volume. Use the path of
the folder in place of the volume name.

#### Configuring the OpenVPN Server

The OpenVPN service will require clients to authenticate using certificates.
The EasyRSA tools installed on the Docker image will allow for the creation of
the client-side certificates.

To be able to manage the certificates a CA needs to be created and configured
as part of the OpenVPN server configuration.

To configure the OpenVPN server the `init` command must be used.

```
docker container run --volume OPENVPN_VOL:/data:rw --rm fscm/openvpn [options] init
```

* `-c CN` - *[required]* The Common Name to use for the CA certificate.
* `-C` - Enables the client-to-client option.
* `-d` - Disables the built in external DNS.
* `-g` - Disables the NAT routing and Default Gateway.
* `-n ADDRESS` - Sets a Name Server to be pushed to the clients.
* `-p RULE` - Sets a rule to be pushed to the clients.
* `-r ROUTE` - Sets a route to be added on the client side (e.g.: '10.0.0.0/16').
* `-s CIDR` - The OpenVPN service subnet (e.g.: '172.16.0.0/24').
* `-u ADDRESS` - *[required]* The OpenVPN server public DNS name. Should be in the form of (udp|tcp)://<server_dns_name>:<server_port> .

After this step the OpenVPN server and a new CA should be configured and ready
to be used.

This step can take some time to finish.

An example on how to configure the OpenVPN server:

```
docker container run --volume my_openvpn:/data:rw --rm fscm/openvpn -c vpn.mydomain.com -n 8.8.8.8 -n 8.8.4.4 -p 'route 10.69.0.0 255.255.0.0' -s 172.16.0.0/16 -u udp://vpn.mydomain.com:1194 init
```

**Note:** All the configuration files will be created and placed on the Docker
volume.

#### Start the OpenVPN Server

After configuring the OpenVPN server the same can now be started.

Starting the OpenVPN server can be done with the `start` command.

```
docker container run --volume OPENVPN_VOL:/data:rw --detach --publish 1194:1194/udp --cap-add=NET_ADMIN --device=/dev/net/tun fscm/openvpn start
```

The Docker options `--cap-add=NET_ADMIN` and `--device=/dev/net/tun` are
required for the container to be able to start.

To help managing the container and the OpenVPN instance a name can be given to
the container. To do this use the `--name <NAME>` docker option when starting
the server   

An example on how the OpenVPN service can be started:

```
docker container run --volume my_openvpn:/data:rw --detach --publish 1194:1194/udp --cap-add=NET_ADMIN --device=/dev/net/tun --name my_openvpn fscm/openvpn start
```

To see the output of the container that was started use the following command:

```
docker container attach CONTAINER_ID
```

Use the `ctrl+p` `ctrl+q` command sequence to detach from the container.

#### Stop the OpenVPN Server

If needed the OpenVPN server can be stoped and later started again (as long as
the command used to perform the initial start was as indicated before).

To stop the server use the following command:

```
docker container stop CONTAINER_ID
```

To start the server again use the following command:

```
docker container start CONTAINER_ID
```

### OpenVPN Status

The OpenVPN server status can be check in two ways.

The first way is by looking at the OpenVPN server output data using the
docker command:

```
docker container logs CONTAINER_ID
```

The second way would be by looking at the OpenVPN server status file. This can
be done with the **ovpn_status** command:

```
docker container exec --interactive --tty CONTAINER_ID ovpn_status
```

### Adding OpenVPN Users

Creating credentials for the OpenVPN service can be done using the
**ovpn_addclient** command:

```
docker container exec --interactive --tty CONTAINER_ID ovpn_addclient -u USERNAME
```

### Obtain the OpenVPN Client Configurations

Getting the OpenVPN client configurations for one user can be done using the
**ovpn_getclient** command:

```
docker container exec --interactive --tty CONTAINER_ID ovpn_getclient -u USERNAME
```

The output of this command can be copied or redirect to a file with the
extension *.ovpn*. This file should be the one used by the user to configure
the OpenVPN client.

### Deleting OpenVPN Users

Removing credentials from the OpenVPN service can be done using the
**ovpn_delclient** command:

```
docker container exec --interactive --tty CONTAINER_ID ovpn_delclient -u USERNAME
```

This operation may require the container to be restarted.

## Build

Build instructions can be found
[here](https://github.com/fscm/docker-openvpn/blob/master/README.build.md).

## Versioning

This project uses [SemVer](http://semver.org/) for versioning. For the versions
available, see the [tags on this repository](https://github.com/fscm/docker-openvpn/tags).

## Authors

* **Frederico Martins** - [fscm](https://github.com/fscm)

See also the list of [contributors](https://github.com/fscm/docker-openvpn/contributors)
who participated in this project.
