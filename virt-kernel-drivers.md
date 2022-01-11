# linux-virt kernel drivers, both compiled in and loadable modules

| Config name     | Type | Value | Arch | Hypervisor | Notes |
|:---------------:|:----:|:-----:|:----:|:----------:|:-----:|
| CONFIG_ACPI_AC | tri | **n** | aarch64 x86 x86_64 | all | No sense for linux-virt to provide |
| CONFIG_ACPI_BATTERY | tri | **n** | aarch64 x86 x86_64 | all | No sense for linux-virt to provide |
| CONFIG_ACPI_BUTTON | tri | **m** ?? | aarch64 x86 x86_64 | all | CONFIG_ACPI_TINY_POWER_BUTTON can do same thing without requiring acpid daemon |
| CONFIG_ACPI_FAN | tri | **n** | aarch64 x86 x86_64 | all | No sense for linux-virt to provide |
| CONFIG_ACPI_SBS | tri | **n** | aarch64 x86 x86_64 | all | No sense for linux-virt to provide |
| CONFIG_ACPI_THERMAL | tri | **n** | aarch64 x86 x86_64 | all | No sense for linux-virt to provide |
| CONFIG_ACPI_TINY_POWER_BUTTON | tri | **m** | aarch64 x86 x86_64 | all ||
| CONFIG_ACPI_TINY_POWER_BUTTON_SIGNAL | int | **12** | aarch64 x86 x86_64 | all | Specify USR2 which Busybox's init accepts for "poweroff" situations |
| CONFIG_ACRN_GUEST | bool | y | ?? | ACRN ||
! CONFIG_ARCH_RANDOM | bool | **y** | x86 x86_64 | all | For Intel RDRAND CPU instruction. Should this be enabled for VMs? |
| CONFIG_CPU_FREQ | bool | n | ??? x86 x86_64 | all | No sense for linux-virt to provide |
| CONFIG_CPU_IDLE_GOV_HALTPOLL | bool | y | ?? x86 x86_64 | all ||
| CONFIG_CPU_IDLE_GOV_LADDER | bool | **n** | ?? x86 x86_64 | all | No sense for linux-virt to provide |
| CONFIG_GCC_PLUGIN_LATENT_ENTROPY | bool | **y** | ??? | all | Should we disable this? |
| CONFIG_HVC_DRIVER | bool | y | all? | Xen | cannot be built as module |
| CONFIG_HVC_XEN | bool | y | ?? | Xen | cannot be built as module |
| CONFIG_HVC_XEN_FRONTEND | bool | y | ?? | Xen | cannot be built as module |
| CONFIG_HW_RANDOM_TPM | bool | y | ?? | all? | cannot be built as module|
| CONFIG_HW_RANDOM_VIRTIO | tri | m | ?? | KVM ||
| CONFIG_HYPERVISOR_GUEST | bool | y | x86 x86_64 | all ||
| CONFIG_JAILHOUSE_GUEST | bool | y | ?? | Jailhouse ||
| CONFIG_KVM | tri | m | ?? | KVM | for nested virtualisation |
| CONFIG_KVM_AMD | tri | m | ?? | KVM | for nested virtualisation |
| CONFIG_KVM_AMD_SEV | tri | m | ?? | KVM | for nested virtualisation |
| CONFIG_KVM_GUEST | bool | y | ? | KVM ||
| CONFIG_KVM_INTEL | tri | m | ?? | KVM | for nested virtualisation |
| CONFIG_KVM_XEN | bool | **n** | ?? | KVM | do we want to support running Xen Guests on KVM? |
| CONFIG_NO_HZ | bool | **n** | ?? | all | legacy setting no longer required |
| CONFIG_PARAVIRT | bool | y | armv7 aarch64 x86 x86_64 | all ||
| CONFIG_PARAVIRT_SPINLOCKS | bool | y | x86 x86_64 | KVM Xen ||
| CONFIG_PARAVIRT_TIME_ACCOUNTING | bool | **y??** | armv7 aarch64 x86 x86_64 | all ||
| CONFIG_TCG_TIS | tri | m | ??? | KVM ||
| CONFIG_TCG_TPM | tri | m | ??? | Xen ||
| CONFIG_TCG_XEN | tri | m | ??? | Xen ||
| CONFIG_USELIB | bool | **n** | ?? | all | legacy setting no longer required |
| CONFIG_XEN | bool | y | armv7 aarch64 x86 x86_64 | Xen ||
| CONFIG_XEN_512GB | bool | y | x86 x86_64 | Xen ||
| CONFIG_XEN_DOM0 | bool | **n** | armv7 aarch64 x86 x86_64 | Xen | For dom0 use the linux-lts kernel instead as it supports real hardware |
| CONFIG_XEN_PV | bool | y | ?? | Xen ||
| CONFIG_XEN_PVH | bool | y | ?? | Xen ||
| CONFIG_XEN_PVHVM_GUEST | bool | y | ?? | Xen ||
| CONFIG_VIRTIO_CONSOLE | tri | m | ?? | ||
| CONFIG_VIRTUALIZATION | bool | y | ?? | all | for nested virtualisation |


# Uncategorised yet

| Config name     | Type | Value | Arch | Hypervisor | Notes |
|:---------------:|:----:|:-----:|:----:|:----------:|:-----:|
| CONFIG_XEN_FBDEV_FRONTEND=y | | | | | |
| CONFIG_XEN_BLKDEV_FRONTEND=y | | | | | |
| CONFIG_XEN_NETDEV_FRONTEND=y | | | | | |
