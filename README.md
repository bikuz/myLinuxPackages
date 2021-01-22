# My LINUX packages setup and Configuration
    - look into environment.yml for the packages
    - it configure the postgresql in conda environment ready for remote connection and start in system boot
    - it also install geoserver and configure to start in system boot

## 1) Run the following command in terminal
    wget https://raw.githubusercontent.com/bikuz/myLinuxPackages/master/install/install_myApps.sh
    bash install_myApps.sh
    
## 2) install packages including geoserver
    bash install_myApps.sh --install-geoserver
    
## 3) To install packages using conda, please see following url
    https://docs.conda.io/projects/conda/en/latest/user-guide/tasks/manage-pkgs.html
