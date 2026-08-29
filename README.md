# MarinhoLab `sas` noncommercial images

`sas` images with the [CC BY-NC 4.0 (noncommercial) packages](https://smartarmstack.github.io/)
installed on top of the [`murilomarinho/sas`](https://hub.docker.com/r/murilomarinho/sas)
base image. The base image already provides Ubuntu, ROS 2, the `sas` LGPL packages
and `dqrobotics`.

## Overview

| `sas`   | `ROS`   | `base`                       | `ubuntu`   |
|---------|---------|------------------------------|------------|
| `jazzy` | `jazzy` | `murilomarinho/sas:jazzy`    | `noble`    |

## Usage

```console
docker run -it ghcr.io/marinholab/sas-full:jazzy
```

## Base images

All base images listed for trackability.

- `murilomarinho/sas`: https://hub.docker.com/r/murilomarinho/sas
- `SmartArmStack` noncommercial packages: https://smartarmstack.github.io/

## License

The noncommercial packages are licensed under
[CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/) for noncommercial use only.
Commercial licensing available by contacting contact@uominnovationfactory.com.
