#!/bin/zsh

lines=(
"███████╗███████╗███████╗███████╗███████╗███████╗███████╗"
"╚══════╝╚══════╝╚══════╝╚══════╝╚══════╝╚══════╝╚══════╝"
)

text=(
"██╗     ███████╗████████╗███████╗     ██████╗  ██████╗ "
"██║     ██╔════╝╚══██╔══╝██╔════╝    ██╔════╝ ██╔═══██╗"
"██║     █████╗     ██║   ███████╗    ██║  ███╗██║   ██║"
"██║     ██╔══╝     ██║   ╚════██║    ██║   ██║██║   ██║"
"███████╗███████╗   ██║   ███████║    ╚██████╔╝╚██████╔╝"
"╚══════╝╚══════╝   ╚═╝   ╚══════╝     ╚═════╝  ╚═════╝"
)

# Function to get system information
get_system_info() {
    local user=$(whoami)
    local hostname=$(hostname)
    local current_time=$(date "+%Y-%m-%d %H:%M:%S")
    local uptime_info=$(uptime | sed 's/.*up \([^,]*\).*/\1/')
    local os_info=$(sw_vers -productName 2>/dev/null || uname -s)
    local arch=$(uname -m)
    
    echo "\033[38;5;111m┌─ \033[38;5;111mSystem Information \033[38;5;111m─────────────────────────────────┐"
    printf "\033[38;5;111m│ \033[38;5;105m%-23s \033[38;5;111m│ \033[38;5;103m%-27s \033[38;5;111m│\n" "User:" "$user"
    printf "\033[38;5;111m│ \033[38;5;105m%-23s \033[38;5;111m│ \033[38;5;103m%-27s \033[38;5;111m│\n" "Hostname:" "$hostname"
    printf "\033[38;5;111m│ \033[38;5;105m%-23s \033[38;5;111m│ \033[38;5;103m%-27s \033[38;5;111m│\n" "Time:" "$current_time"
    printf "\033[38;5;111m│ \033[38;5;105m%-23s \033[38;5;111m│ \033[38;5;103m%-27s \033[38;5;111m│\n" "Uptime:" "$uptime_info"
    printf "\033[38;5;111m│ \033[38;5;105m%-23s \033[38;5;111m│ \033[38;5;103m%-27s \033[38;5;111m│\n" "OS:" "$os_info ($arch)"
    echo "\033[38;5;111m└───────────────────────────────────────────────────────┘\033[0m"
}

# Main execution
main() {
    echo
    for i in {0..2}; do
        printf "\033[38;5;%dm%s\033[0m\n" "111" "${lines[i]}"
    done

    for i in {0..6}; do
        printf "\033[38;5;%dm%s\033[0m\n" "105" "${text[i]}"
    done


    for i in {0..2}; do
        printf "\033[38;5;%dm%s\033[0m\n" "111" "${lines[$i]}"
    done

    
    get_system_info

    echo
}

# Run the script
main
