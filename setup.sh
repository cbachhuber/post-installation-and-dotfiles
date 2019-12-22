#!/bin/bash

set -eu

# TODO split me up into sub functions, called from separate scripts

OS_TWEAKS=false
PROGRAMS=false
CONFIGURE_GIT=false
CONFIGURE_ZSH=false

# Let the user clone this repo to any location
DOTFILES_PATH="$( cd "$(dirname "$0")" ; pwd -P )"
CONFIG_FOLDER=""$DOTFILES_PATH"/config"

POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -o|--os-tweaks)
        OS_TWEAKS=true
        shift # past argument
        ;;
        -p|--programs)
        PROGRAMS=true
        shift # past argument
        ;;
        -g|--configure-git)
        CONFIGURE_GIT=true
        shift # past argument
        ;;
        -z|--configure-zsh)
        CONFIGURE_ZSH=true
        shift # past argument
        ;;
        -h|--help)
        printf "Usage: $0 [-o] [-p] [-g] [-z]\n
This script sets up your OS with a reasonable config and programs. 
Via flags, you have the option to execute a subset of the script steps. 
For more details, see README.md.\n
-o      Walk through OS tweaks setup
-p      Install programs
-g      Git configuration
-z      Oh-my-zsh configuration\n"
        exit 0
        ;;
        *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [ "$OS_TWEAKS" = false ] && [ "$PROGRAMS" = false ] && \
   [ "$CONFIGURE_GIT" = false ] && [ $"CONFIGURE_ZSH" = false ]; then
    OS_TWEAKS=true
    PROGRAMS=true
    CONFIGURE_GIT=true
    CONFIGURE_ZSH=true
fi

prompt_message_and_wait_for_input()
{
    echo "$1"
    sleep 0.5
    read -p "Waiting for you to press [enter]..." DUMMY_VARIABLE
    printf "Continuing execution!\n\n"
    sleep 0.5
}

run_command_and_ask_to_close()
{
    echo "Please close the new window(s) when you're done."
    $@ > /dev/null 2>&1
    printf "Windows closed, continuing execution!\n\n"
    sleep 0.5
}

ask_user_to_execute_command()
{
    if [ "$#" = 3 ]; then
        QUESTION=$1
        COMMAND=$2
        NO_MESSAGE=$3
        while true; do
        read -p "$QUESTION (y/n) " yn
        case $yn in
            [Yy]* ) $COMMAND; break;;
            [Nn]* ) echo "$NO_MESSAGE"; break;;
            * ) echo "Please answer yes or no.";;
        esac
        done
    else
        echo "Call me as 'question' 'command to execute' 'Message if no is chosen'"
    fi
}


walk_through_os_tweaks()
{
    echo "Walking through OS tweaks"
    GNOME_TWEAKS_INSTALLED=$(dpkg -l | grep gnome-tweaks | wc -l)  # gnome-tweaks is not part of the default Ubuntu packages: http://releases.ubuntu.com/bionic/ubuntu-18.04.3-desktop-amd64.manifest
    if [ $GNOME_TWEAKS_INSTALLED = 0 ]; then
        sudo apt install -y gnome-tweaks gnome-shell-extension-weather gnome-shell-extension-system-monitor gnome-shell-extension-impatience
        printf "Gnome extensions require a logout and login to become visible in gnome settings.
        Please log out and back in, and restart this script."
        return 0
    else
        echo "Welcome back! Let's continue with gnome extension settings."
        echo " 1. To use the nice dark mode in your OS, change Appearance->Themes->Applications to 'Adwaita-dark'."
        echo " 2. Also consider changing your cursor appearance"
        echo " 3. Under Top Bar, enable date and week numbers"
        echo " 4. Under 'Extensions', enable and configure openweather and System-monitor."
        run_command_and_ask_to_close gnome-tweaks
    fi

    echo "Add a german, english, or other keyboard layout, if you like."
    run_command_and_ask_to_close gnome-control-center region
    echo "Fix your key repeat delay and rate by clicking 'Typing->Repeat Keys'. Be careful to not set the delay too low, and the rate too high. Experiment with the text editor on the side. Note: the speed slider is inverse! Pushing it leftwards means higher repeat rate."
    run_command_and_ask_to_close gedit & gnome-control-center universal-access
    echo "Fix your automatic suspend delays: click on 'Automatic suspend', then choose to your liking."
    run_command_and_ask_to_close gnome-control-center power
}

install_programs()
{
    echo "Installing recommended programs"
    # TODO Browser selection
    echo "Which browser should we install? (chromium/chrome/no_additional)?"
    sudo apt install -y chromium-browser

    # Media playback and recording
    sudo apt install -y vlc kazam ubuntu-restricted-extras

    # Image and graphics tools
    echo "Install gimp and inkscape?"
    sudo apt install -y gimp inkscape imagemagick
    # TODO fix imagemagick permissions

    # Other tools
    sudo apt install -y unrar htop iotop bmon

    # Essential dev tools
    sudo apt install -y neovim zsh git terminator curl python3-dev python3-pip python3-setuptools build-essential cmake libgtest-dev tree
    sudo apt install -y powerline fonts-powerline
    prompt_message_and_wait_for_input "Let terminator show more lines: open terminator, right-click into the empty space, click 'Preferences->Profile->Scrolling'. Under 'Scrollback', set the number of lines to something more reasonable, e.g. 5000 lines."
}

configure_git()
{
    echo "Configuring git"
    sudo apt install -y git
    # Git configuration
    read -p "Enter your git user name: " GIT_NAME
    read -p "Enter your git mail address: " GIT_MAIL
    git config --global user.name $GIT_NAME
    git config --global user.email $GIT_MAIL
    git config --global core.pager 'less -F -X'  # use less only if you output does not fit to the screen
    git config --global core.excludesFile "$CONFIG_FOLDER"/global_gitignore
    echo "[include]
    	path = /home/$(whoami)/.dotfiles/config/gitconfig" >> ~/.gitconfig  # $HOME expansion not supported in gitconfig, need absolute path

    # Git Editor
    ask_user_to_execute_command "Would you like to use vim as git editor?" "git config --global core.editor 'vim'" "Not using vim as git editor" # more handy than nano when closing with 'ZZ' (discard with ':cq')
}

configure_oh_my_zsh()
{
    echo "Configuring Oh-my-zsh"
    sudo apt install -y zsh wget

    # ZSH as default shell
    ask_user_to_execute_command "Would you like to use ZSH as your default shell?" "chsh -s $(which zsh)" "Not using ZSH as default shell."

    # Download oh-my-zsh
    sh -c "$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

    # Use oh-my-zsh to install zsh plugins
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

    if [ -f ~/.zshrc ]; then
        echo "Backing up old zshrc to $DOTFILES_PATH/backups/zshrc"
        mkdir -p "$DOTFILES_PATH"/backups
        mv ~/.zshr "$DOTFILES_PATH"/backups/zshrc
    fi

    ln -s "$CONFIG_FOLDER"/zshrc ~/.zshrc
}

if [ "$OS_TWEAKS" = true ]; then walk_through_os_tweaks; fi
if [ "$PROGRAMS" = true ]; then install_programs; fi
if [ "$CONFIGURE_GIT" = true ]; then configure_git; fi
if [ "$CONFIGURE_ZSH" = true ]; then configure_oh_my_zsh; fi

# TODO neovim configuration. Use vimrc!

# TODO Consider doing the following in a loop
echo "Choose your development language"
echo "Choose your C++ IDE"

exit 0
