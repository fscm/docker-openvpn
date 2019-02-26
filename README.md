# OpenVPN for Docker

Docker image that should be used to start an OpenVPN server.

## Synopsis

This script will create a Docker image with OpenVPN installed and with all
of the required initialisation scripts.

The Docker image resulting from this script should be the one used to
instantiate an OpenVPN server.

## Getting Started

There are a couple of things needed for the script to work.

### Prerequisites

Docker, either the Community Edition (CE) or Enterprise Edition (EE), needs to
be installed on your local computer.

#### Docker

Docker installation instructions can be found
[here](https://docs.docker.com/install/).

### Usage

In order to create a Docker image using this Dockerfile you need to run the
`docker` command with a few options.

```
docker build --squash --force-rm --no-cache --quiet --tag <USER>/<IMAGE>:<TAG> <PATH>
```

* `<USER>` - *[required]* The user that will own the container image (e.g.: "johndoe").
* `<IMAGE>` - *[required]* The container name (e.g.: "openvpn").
* `<TAG>` - *[required]* The container tag (e.g.: "latest").
* `<PATH>` - *[required]* The location of the Dockerfile folder.

A build example:

```
docker build --squash --force-rm --no-cache --quiet --tag johndoe/my_openvpn:latest .
```

To clean the _<none>_ image(s) left by the `--squash` option the following
command can be used:

```
docker rmi `docker images --filter "dangling=true" --quiet`
```

### Instantiate a Container

In order to end up with a functional OpenVPN service - after having build
the container - some configurations have to be performed.

To help perform those configurations a small set of commands is included on the
Docker container.

- `help` - Usage help.
- `init` - Configure the OpenVPN service.
- `start` - Start the OpenVPN service.

To store the configuration settings of the OpenVPN server as well as the users
A couple of volumes should be created and added the the container when running
the same.

#### Creating Volumes

To be able to make all of the OpenVPN configuration settings persistent, the
same will have to be stored on two different volumes, one for the OpenVPN and
the other for the CA information.

Creating volumes can be done using the `docker` tool. To create a volume use
the following command:

```
docker volume create --name <VOLUME_NAME>
```

Two create the two required volumes the following set of commands can be used:

```
docker volume create --name my_openvpn
docker volume create --name my_easyrsa
```

**Note:** Local folders can also be used instead of the volumes. Use the path
of the folders in place of the volume names.

#### Configuring the OpenVPN Server

The OpenVPN service will require clients to authenticate using certificates.
The EasyRSA tools installed on the Docker image will allow for the creation of
the client-side certificates.

To be able to manage the certificates a CA needs to be created and configured
as part of the OpenVPN server configuration.

To configure the OpenVPN server the `init` command must be used.

```
docker run --volume <OPENVPN_VOL>:/data/openvpn:rw --volume <EASYRSA_VOL>:/data/easyrsa:rw --rm <USER>/<IMAGE>:<TAG> [options] init
```

* `-c <CN>` - *[required]* The Common Name to use for the CA certificate.
* `-C` - Enables the client-to-client option.
* `-d` - Disables the built in external DNS.
* `-g` - Disables the NAT routing and Default Gateway.
* `-n <ADDRESS>` - Sets a Name Server to be pushed to the clients.
* `-p <RULE>` - Sets a rule to be pushed to the clients.
* `-r <ROUTE>` - Sets a route to be added on the client side (e.g.: '10.0.0.0/16').
* `-s <CIDR>` - The OpenVPN service subnet (e.g.: '172.16.0.0/24').
* `-u <ADDRESS>` - *[required]* The OpenVPN server public DNS name. Should be in the form of (udp|tcp)://<server_dns_name>:<server_port> .

After this step the OpenVPN server and a new CA should be configured and ready
to be used.

This step can take some time to finish.

An example on how to configure the OpenVPN server:

```
docker run --volume my_openvpn:/data/openvpn:rw --volume my_easyrsa:/data/easyrsa:rw --rm johndoe/my_openvpn:latest -c vpn.johndoe.com -n 8.8.8.8 -n 8.8.4.4 -p 'route 10.69.0.0 255.255.0.0' -s 172.16.0.0/16 -u udp://vpn.johndoe.com:1194 init
```

#### Start the OpenVPN Server

After configuring the OpenVPN server the same can now be started.

Starting the OpenVPN server can be done with the `start` command.

```
docker run --volume <OPENVPN_VOL>:/data/openvpn:rw --volume <EASYRSA_VOL>:/data/easyrsa:rw --detach --interactive --tty -p 1194:1194/udp --cap-add=NET_ADMIN --device=/dev/net/tun <USER>/<IMAGE>:<TAG> start
```

The Docker options `--cap-add=NET_ADMIN` and `--device=/dev/net/tun` are
required for the container to be able to start.

To help managing the container and the OpenVPN instance a name can be given to the container. To do this use the `--name <NAME>` docker option when starting the server   

An example on how the OpenVPN service can be started:

```
docker run --volume my_openvpn:/data/openvpn:rw --volume my_easyrsa:/data/easyrsa:rw --detach --interactive --tty -p 1194:1194/udp --cap-add=NET_ADMIN --device=/dev/net/tun --name my_openvpn johndoe/my_openvpn:latest start
```

To see the output of the container that was started use the following command:

```
docker attach <CONTAINER_ID>
```

Use the `ctrl+p` `ctrl+q` command sequence to detach from the container.

#### Stop the OpenVPN Server

If needed the OpenVPN server can be stoped and later started again (as long as
the command used to perform the initial start was as indicated before).

To stop the server use the following command:

```
docker stop <CONTAINER_ID>
```

To start the server again use the following command:

```
docker start <CONTAINER_ID>
```

### OpenVPN Status

The OpenVPN server status can be check in two ways.

The first way is by looking at the OpenVPN server output data using the
docker command:

```
docker container logs <CONTAINER_ID>
```

The second way would be by looking at the OpenVPN server status file. This can
be done with the **ovpn_status** command:

```
docker exec -it <CONTAINER_ID> ovpn_status
```

### Adding OpenVPN Users

Creating credentials for the OpenVPN service can be done using the
**ovpn_addclient** command:

```
docker exec -it <CONTAINER_ID> ovpn_addclient -u <USERNAME>
```

### Obtain the OpenVPN Client Configurations

Getting the OpenVPN client configurations for one user can be done using the
**ovpn_getclient** command:

```
docker exec -it <CONTAINER_ID> ovpn_getclient -u <USERNAME> > <USERNAME>-<VPN_DOMAIN_TLD>.ovpn

Usage: ovpn_getclient [options] > myuser-vpn_mydomain_tld.ovpn
```

The resulting *.ovpn* file should be the one used by the user to configure the
OpenVPN client.

### Deleting OpenVPN Users

Removing credentials from the OpenVPN service can be done using the
**ovpn_delclient** command:

```
docker exec -it <CONTAINER_ID> ovpn_delclient -u <USERNAME>
```

This operation may require the container to be restarted.

### Add Tags to the Docker Image

Additional tags can be added to the image using the following command:

```
docker tag <image_id> <user>/<image>:<extra_tag>
```

### Push the image to Docker Hub

After adding an image to Docker, that image can be pushed to a Docker registry... Like Docker Hub.

Make sure that you are logged in to the service.

```
docker login
```

When logged in, an image can be pushed using the following command:

```
docker push <user>/<image>:<tag>
```

Extra tags can also be pushed.

```
docker push <user>/<image>:<extra_tag>
```

## Contributing

1. Fork it!
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Submit a pull request

Please read the [CONTRIBUTING.md](CONTRIBUTING.md) file for more details on how
to contribute to this project.

## Versioning

This project uses [SemVer](http://semver.org/) for versioning. For the versions
available, see the [tags on this repository](https://github.com/fscm/docker-openvpn/tags).

## Authors

* **Frederico Martins** - [fscm](https://github.com/fscm)

See also the list of [contributors](https://github.com/fscm/docker-openvpn/contributors)
who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE)
file for details
