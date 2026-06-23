#!/bin/bash
# user_data.sh
# Runs as root on first boot. Logs to /var/log/user-data.log

## Note: Don't copy fully- copy the installation steps based on your needs.
set -e
exec > /var/log/user-data.log 2>&1

echo '============================================'
echo 'Aarvitex Maven Server Bootstrap'
echo "Started: $(date)"
echo '============================================'

# ── Step 1: System update ──────────────────────────────────────────
echo '>>> Updating system packages...'
dnf update -y

# ── Step 2: Install Java 17 (Amazon Corretto) ──────────────────────
echo '>>> Installing Java 17 Amazon Corretto...'
dnf install java-17-amazon-corretto -y

# Verify Java
java -version
echo "JAVA_HOME set to: $(dirname $(dirname $(readlink -f $(which java))))"

# Set JAVA_HOME globally
echo 'export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))' >> /etc/profile
echo 'export PATH=$PATH:$JAVA_HOME/bin' >> /etc/profile

# ── Step 3: Install Maven 3.9.13 ───────────────────────────────────
echo '>>> Installing Apache Maven 3.9.13...'
cd /opt
wget https://archive.apache.org/dist/maven/maven-3/3.9.13/binaries/apache-maven-3.9.13-bin.tar.gz

# Extract
sudo tar -xvzf apache-maven-3.9.13-bin.tar.gz

# Set environment variables
echo 'export M2_HOME=/opt/apache-maven-3.9.13' | sudo tee -a /etc/profile
echo 'export PATH=$PATH:$M2_HOME/bin'         | sudo tee -a /etc/profile
source /etc/profile

# Verify
mvn -version

#Tomcat install
cd /opt
sudo wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.115/bin/apache-tomcat-9.0.115.tar.gz
sudo tar -xvzf apache-tomcat-9.0.115.tar.gz
sudo mv apache-tomcat-9.0.115 tomcat9

# Start Tomcat
sudo /opt/tomcat9/bin/startup.sh

# ── Step 4: Install Git ─────────────────────────────────────────────
sudo yum install git -y
cd /opt
git clone https://github.com/Aarvitexsathya/aarvitex-webapp.git

#Build the project
cd /opt/aarvitex-webapp/aarvitex-webapp
mvn clean package

#Deploy the war
sudo cp /opt/aarvitex-webapp/aarvitex-webapp/target/AarvitexWebApp.war /opt/tomcat9/webapps/

# ── Step 5: Install SonarQube 9.9.8 (Port 9000) ───────────────────
echo '>>> Installing SonarQube...'

# System limits required by Elasticsearch
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
echo "fs.file-max=65536" >> /etc/sysctl.conf
sysctl -p

cat >> /etc/security/limits.conf << EOF
sonar   -   nofile   65536
sonar   -   nproc    4096
EOF

# Create sonar user (SonarQube won't run as root)
useradd sonar
echo "sonar:sonar123" | chpasswd

# Download and install
cd /opt
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.8.100196.zip
unzip sonarqube-9.9.8.100196.zip
mv sonarqube-9.9.8.100196 sonarqube

# Set ownership
chown -R sonar:sonar /opt/sonarqube

# Set run-as user
sed -i 's/#RUN_AS_USER=/RUN_AS_USER=sonar/' /opt/sonarqube/bin/linux-x86-64/sonar.sh

# Start SonarQube
su - sonar -c "/opt/sonarqube/bin/linux-x86-64/sonar.sh start"

echo '>>> SonarQube installed — http://<IP>:9000 (admin/admin)'

# ── Step 6: Install Nexus (Port 8081) 
echo '>>> Installing Nexus...'

# Create nexus user
useradd nexus
echo "nexus:nexus123" | chpasswd

# Download and install
cd /opt
wget https://download.sonatype.com/nexus/3/nexus-3.80.0-06-linux-x86_64.tar.gz
tar -zxvf nexus-3.80.0-06-linux-x86_64.tar.gz
mv nexus-3.80.0-06 nexus

# Set ownership and permissions
chown -R nexus:nexus /opt/nexus
chown -R nexus:nexus /opt/sonatype-work
chmod -R 775 /opt/nexus
chmod -R 775 /opt/sonatype-work

# Start Nexus
su - nexus -c "/opt/nexus/bin/nexus start"

echo '>>> Nexus installed — http://<IP>:8081'
echo '>>> Nexus admin password: cat /opt/sonatype-work/nexus3/admin.password'

echo '============================================'
echo 'Bootstrap complete!'
echo "Finished: $(date)"
echo '============================================'