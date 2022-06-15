defaultentry = "Phoenix"
timeout = 0
backgroundcolor = colors.black
selectcolor = colors.orange
titlecolor = colors.lightGray

menuentry "Phoenix" {
    description "Boot Phoenix normally.";
    kernel "/root/boot/kernel.lua";
    args "root=/root splitkernpath=/boot/kernel.lua.d init=/bin/cash.lua";
}

menuentry "CraftOS" {
    description "Boot into CraftOS.";
    craftos;
}
