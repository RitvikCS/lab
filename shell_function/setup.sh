#!/bin/bash

set -e 

WITH_KUBERNETES=false
EKS_CLUSTER_NAME=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

show_progress() {
    local duration=${1:-3}
    local cols=$(tput cols)
    local bar_width=$((cols - 20))
    
    echo -ne "${CYAN}Progress: ${NC}"
    for ((i=0; i<=bar_width; i++)); do
        echo -ne "${GREEN}#${NC}"
        sleep $(echo "scale=3; $duration/$bar_width" | bc -l 2>/dev/null || echo "0.1")
    done
    echo -e " ${GREEN}[OK]${NC}"
}

print_banner() {
    clear
    echo -e "${PURPLE}"
    echo "╔════════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                                    ║"
    echo "║          ██╗███╗   ██╗███████╗████████╗ █████╗ ███╗   ██╗ ██████╗███████╗          ║"
    echo "║          ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗████╗  ██║██╔════╝██╔════╝          ║"
    echo "║          ██║██╔██╗ ██║███████╗   ██║   ███████║██╔██╗ ██║██║     █████╗            ║"
    echo "║          ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║╚██╗██║██║     ██╔══╝            ║"
    echo "║          ██║██║ ╚████║███████║   ██║   ██║  ██║██║ ╚████║╚██████╗███████╗          ║"
    echo "║          ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝          ║"
    echo "║                                                                                    ║"
    echo "║                     ███████╗███████╗████████╗██╗   ██╗██████╗                      ║"
    echo "║                     ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗                     ║"
    echo "║                     ███████╗█████╗     ██║   ██║   ██║██████╔╝                     ║"
    echo "║                     ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝                      ║"
    echo "║                     ███████║███████╗   ██║   ╚██████╔╝██║                          ║"
    echo "║                     ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝                          ║"
    echo "║                                                                                    ║"
    echo "║                             AWS EC2 Instance Setup                                 ║"
    echo "║                                                                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    sleep 2
}

print_header() {
    local title="$1"
    local icon="$2"
    local cols=$(tput cols)
    local title_length=${#title}
    local padding=$(( (cols - title_length - 6) / 2 ))

    echo ""
    echo -e "${BLUE}╔$(printf '═%.0s' $(seq 1 $((cols-2))))╗${NC}"
    printf "${BLUE}║${NC}%*s${icon} ${BOLD}${WHITE}%s${NC} ${icon}%*s${BLUE}║${NC}\n" $padding "" "$title" $padding ""
    echo -e "${BLUE}╚$(printf '═%.0s' $(seq 1 $((cols-2))))╝${NC}"
}

run_command() {
  $1
  local status=$?
  if [ $status -eq 0 ]; then
    echo -e "${GREEN}Installation Complete!${NC}\n"
  elif [ $status -eq 1 ]; then
    echo -e "${RED}Installation Failed!${NC}\n"
  else
    echo -e "${YELLOW}Installation Complete (with warnings)!${NC}\n"
  fi
}

install_kubectl() {
    print_header "Installing kubectl" "[K8S]"
 
    run_command "curl -LO 'https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl'"
 
    run_command "sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl"
 
    echo 'source <(kubectl completion bash)' >> ~/.bashrc
    echo 'alias k=kubectl' >> ~/.bashrc
    echo 'complete -F __start_kubectl k' >> ~/.bashrc
 
    echo -e "${GREEN}  [OK] kubectl installed and bash completion configured${NC}"
}

install_helm() {
    print_header "Installing Helm" "[HELM]"
 
    run_command "curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"
    run_command "chmod 700 get_helm.sh"
    run_command "./get_helm.sh"
 
    echo 'source <(helm completion bash)' >> ~/.bashrc
 
    echo -e "${GREEN}  [OK] Helm installed and bash completion configured${NC}"
}

configure_eks() {
    local cluster_name="$1"
    print_header "Configuring EKS Access" "[EKS]"
 
    if ! command -v aws &> /dev/null; then
        echo -e "${YELLOW}  AWS CLI not found, installing...${NC}"
        exit 1
    fi
 
    run_command "aws eks update-kubeconfig --region us-east-2 --name $cluster_name"
 
    echo -e "${CYAN}>> Testing EKS connection...${NC}"
    if kubectl cluster-info > /dev/null 2>&1; then
        echo -e "${GREEN}  [OK] Successfully connected to EKS cluster: $cluster_name${NC}"
        kubectl get nodes --no-headers | wc -l | xargs printf "${CYAN}  [INFO] Cluster has %d nodes${NC}\n"
    else
        echo -e "${YELLOW}  [WARN] Could not connect to cluster. Please check your AWS credentials and cluster name.${NC}"
    fi
}

show_help() {
    echo -e "${BOLD}Instance Setup Script${NC}"
    echo ""
    echo -e "${BOLD}USAGE:${NC}"
    echo "  $0 [OPTIONS]"
    echo ""
    echo -e "${BOLD}OPTIONS:${NC}"
    echo -e "  ${GREEN}--with-kubernetes <cluster-name>${NC}  Install kubectl, helm and configure EKS access"
    echo -e "  ${GREEN}--help${NC}                           Show this help message"
    echo ""
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo "  $0                                    # Basic installation"
    echo "  $0 --with-kubernetes my-eks-cluster   # Install with Kubernetes tools"
    echo ""
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --with-kubernetes)
                if [[ -n "$2" && "$2" != --* ]]; then
                    WITH_KUBERNETES=true
                    EKS_CLUSTER_NAME="$2"
                    shift 2
                else
                    echo -e "${RED}Error: --with-kubernetes requires a cluster name${NC}"
                    exit 1
                fi
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
}

main() {
    parse_arguments "$@"
 
    print_banner
 
    echo -e "${BOLD}[CONFIG] Configuration:${NC}"
    echo -e "${CYAN}  * Basic tools: Terraform, Ansible, Docker, Git${NC}"
    if [ "$WITH_KUBERNETES" = true ]; then
        echo -e "${CYAN}  * Kubernetes tools: kubectl, helm${NC}"
        echo -e "${CYAN}  * EKS cluster: $EKS_CLUSTER_NAME${NC}"
    fi
    echo ""
    read -p "Press Enter to continue or Ctrl+C to abort..."
 
    print_header "System Update" "[UPDATE]"
    run_command "sudo dnf update -y"
    show_progress 2
 
    print_header "Installing Dependencies" "[DEPS]"
    run_command "sudo dnf install -y dnf-utils shadow-utils unzip wget bc"
 
    print_header "Installing Terraform" "[TERRAFORM]"
    run_command "sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo"
    run_command "sudo dnf install -y terraform"
 
    print_header "Installing Ansible" "[ANSIBLE]"
    run_command "sudo dnf install -y ansible"
 
    print_header "Installing Git" "[GIT]"
    run_command "sudo dnf install -y git"
 
    print_header "Installing Python Packages" "[PYTHON]"
    run_command "python3 -m ensurepip --upgrade"
    run_command "pip install kubernetes openshift pyyaml jinja2 netaddr"
 
    # Ansible collections
    collections=(
        "ansible.posix"
        "community.kubernetes"
        "community.general"
        "amazon.aws"
        "kubernetes.core"
    )
    
    print_header "Installing Ansible Collections" "[COLLECTIONS]"
    for collection in "${collections[@]}"; do
        run_command "ansible-galaxy collection install $collection"
    done
    
    print_header "Installing Docker" "[DOCKER]"
    run_command "sudo yum install -y docker"
    run_command "sudo systemctl enable --now docker"
    
    sudo groupadd docker 2>/dev/null || true
    run_command "sudo usermod -aG docker $USER"
    
    echo -e "${CYAN}>> Applying Docker group membership...${NC}"
    newgrp docker << EOF
echo -e "${GREEN}  [OK] Docker group membership applied${NC}"
docker --version > /dev/null 2>&1 && echo -e "${GREEN}  [OK] Docker working without sudo${NC}" || echo -e "${YELLOW}  [WARN] Docker test failed${NC}"
EOF

    if [ "$WITH_KUBERNETES" = true ]; then
        install_kubectl
        install_helm
        configure_eks "$EKS_CLUSTER_NAME"
    fi
    
    print_header "Installation Verification" "[VERIFY]"
    
    echo -e "${BOLD}[INFO] Installed Versions:${NC}"
    echo -e "${GREEN}  [TERRAFORM] $(terraform --version | head -n 1 | cut -d' ' -f2)${NC}"
    echo -e "${GREEN}  [ANSIBLE] $(ansible --version | head -n 1 | cut -d' ' -f3)${NC}"
    echo -e "${GREEN}  [DOCKER] $(docker --version | cut -d' ' -f3 | sed 's/,//')${NC}"
    echo -e "${GREEN}  [GIT] $(git --version | cut -d' ' -f3)${NC}"
    
    if [ "$WITH_KUBERNETES" = true ]; then
        echo -e "${GREEN}  [KUBECTL] $(kubectl version --client --short 2>/dev/null | cut -d' ' -f3)${NC}"
        echo -e "${GREEN}  [HELM] $(helm version --short | cut -d' ' -f1 | sed 's/v//')${NC}"
    fi
    
    echo ""
    print_header "Ansible Collections" "[COLLECTIONS]"
    ansible-galaxy collection list 2>/dev/null | grep -E "^[a-z]" | while read -r collection version _; do
        printf "${CYAN}  %-30s${NC} ${GREEN}%-15s${NC}\n" "$collection" "$version"
    done
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                                  ║${NC}"
    echo -e "${GREEN}║                                                                                  ║${NC}"
    echo -e "${GREEN}║  [SUCCESS] Installation completed successfully!                                  ║${NC}"
    echo -e "${GREEN}║                                                                                  ║${NC}"
    if [ "$WITH_KUBERNETES" = true ]; then
        echo -e "${GREEN}║  ${CYAN}Docker is ready to use without sudo${NC}${GREEN}                         ║${NC}"
        echo -e "${GREEN}║  ${CYAN}Kubernetes tools are ready to use with EKS cluster${NC}${GREEN}          ║${NC}"
    else
        echo -e "${GREEN}║  ${CYAN}Docker is ready to use without sudo${NC}${GREEN}                         ║${NC}"
    fi
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════╝${NC}"
    
    if [ "$WITH_KUBERNETES" = true ]; then
        echo ""
        echo -e "${YELLOW}[TIPS] Quick commands to get started:${NC}"
        echo -e "${CYAN}  docker ps                      ${NC}# List running containers"
        echo -e "${CYAN}  kubectl get nodes              ${NC}# List cluster nodes"
        echo -e "${CYAN}  kubectl get pods --all-namespaces  ${NC}# List all pods"
        echo -e "${CYAN}  helm list                      ${NC}# List Helm releases"
    else
        echo ""
        echo -e "${YELLOW}[TIPS] Quick commands to get started:${NC}"
        echo -e "${CYAN}  docker ps                      ${NC}# List running containers"
        echo -e "${CYAN}  terraform --version            ${NC}# Check Terraform version"
        echo -e "${CYAN}  ansible --version              ${NC}# Check Ansible version"
    fi}

main "$@"
