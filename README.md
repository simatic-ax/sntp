# @simatic-ax/sntp

This repository is still a template, the library will be published soon!

## Description

This library provides functionality to create a NTP (Network time protocol) server on a SIMATIC S7-1500 PLC. This server serves the current PLC time to devices (drive controllers, distributed IO, HMI systems, etc.) in the same network to synchronize to.

## Getting started

Install with Apax:

> If not yet done login to the GitHub registry first.
> More information you'll find [here](https://github.com/simatic-ax/.github/blob/main/docs/personalaccesstoken.md)

```cli
apax add @simatic-ax/sntp
```

Add the namespace in your ST code:

```iec-st
Using Simatic.Ax.sntp;
```

This library is based on the LSTNP library for the S7-1500 in the context of TIA Portal. You can find the original library here:

[https://support.industry.siemens.com/cs/document/109780503](https://support.industry.siemens.com/cs/document/109780503/libraries-for-communication-for-simatic-controllers?dti=0&lc=en-WW)

| Functions   | Description             |
|-------------|-------------------------|
| LSNTP_typeTimestamp | Convert timestamp from LDATE_AND_TIME to NTP timestamp |

| Function Blocks | Description           |
|-----------------|-----------------------|
| LSNTP_Server | Create and run a NTP server |

## Contribution

Thanks for your interest in contributing. Anybody is free to report bugs, unclear documentation, and other problems regarding this repository in the Issues section or, even better, is free to propose any changes to this repository using Merge Requests.

## Markdownlint-cli

This workspace will be checked by the [markdownlint-cli](https://github.com/igorshubovych/markdownlint-cli) (there is also documented ho to install the tool) tool in the CI workflow automatically.
To avoid, that the CI workflow fails because of the markdown linter, you can check all markdown files locally by running the markdownlint with:

```sh
markdownlint **/*.md --fix
```

## License and Legal information

Please read the [Legal information](LICENSE.md)
