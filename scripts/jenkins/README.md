# Jenkins API Token Creation Script

**Version:** 1.1.1  
**Author:** Bogdan Dragos Vasile  
**Description:** Automated Jenkins API token creation for programmatic access

## 📋 Overview

This feature provides automated creation of Jenkins API tokens for secure programmatic access to Jenkins instances. It includes both Python and shell script implementations with comprehensive error handling and testing capabilities.

## 🚀 Features

- ✅ **Automated token creation** with proper CSRF handling
- ✅ **Session management** for secure API communication
- ✅ **Token testing** to verify functionality
- ✅ **Environment file export** for easy integration
- ✅ **Comprehensive error handling** and logging
- ✅ **Command-line interface** with flexible options
- ✅ **Dependency checking** and auto-installation

## 📁 File Structure

```
scripts/jenkins/
├── create_api_token.py      # Main Python implementation
├── create_api_token.sh      # Shell script wrapper
└── README.md               # This documentation
```

## 🛠️ Requirements

### System Requirements
- **Python 3.6+**
- **Bash shell** (for shell script)
- **Internet connectivity** (for dependency installation)

### Python Dependencies
- `requests` library for HTTP communication
- `argparse` for command-line argument parsing
- `json` for JSON handling
- `typing` for type hints

## 📦 Installation

### Automatic Installation
The shell script will automatically check and install missing dependencies:

```bash
# The script will auto-install requests if missing
./scripts/jenkins/create_api_token.sh -u username -p password
```

### Manual Installation
```bash
# Install Python requests library
pip3 install requests

# Make scripts executable
chmod +x scripts/jenkins/create_api_token.sh
chmod +x scripts/jenkins/create_api_token.py
```

## 🔧 Usage

### Shell Script (Recommended)

```bash
# Basic usage
./scripts/jenkins/create_api_token.sh -u cursor -p "P8p8c%4az0"

# With custom token name
./scripts/jenkins/create_api_token.sh -u cursor -p "P8p8c%4az0" -t "my-custom-token"

# With custom Jenkins URL
./scripts/jenkins/create_api_token.sh -u admin -p "password" -j "http://jenkins.example.com"

# With testing and file export
./scripts/jenkins/create_api_token.sh -u cursor -p "P8p8c%4az0" --test --save-to-file .env
```

### Python Script (Direct)

```bash
# Basic usage
python3 scripts/jenkins/create_api_token.py -u cursor -p "P8p8c%4az0"

# Advanced usage
python3 scripts/jenkins/create_api_token.py \
  -u cursor \
  -p "P8p8c%4az0" \
  -t "jenkins-api-token" \
  -j "http://localhost:8080" \
  --test \
  --save-to-file .env
```

## 📋 Command Line Options

| Option | Description | Required | Default |
|--------|-------------|----------|---------|
| `-u, --username` | Jenkins username | ✅ Yes | - |
| `-p, --password` | Jenkins password | ✅ Yes | - |
| `-t, --token-name` | Token name | ❌ No | `jenkins-api-token` |
| `-j, --jenkins-url` | Jenkins URL | ❌ No | `http://localhost:8080` |
| `--test` | Test created token | ❌ No | `false` |
| `--save-to-file` | Save to environment file | ❌ No | - |
| `-h, --help` | Show help message | ❌ No | - |

## 🔐 Security Features

### CSRF Protection
- Automatically handles Jenkins CSRF tokens
- Proper session management
- Secure token transmission

### Error Handling
- Network timeout protection (30 seconds)
- Comprehensive error messages
- Graceful failure handling

### Token Management
- Secure token generation
- Token validation testing
- Environment file export with proper permissions

## 📊 Output Examples

### Successful Token Creation
```
🔑 Jenkins API Token Creator v1.1.1
==================================
🔍 Checking dependencies...
✅ Dependencies check passed
🚀 Creating Jenkins API token...
🔐 Getting CSRF crumb...
✅ Got crumb: 44d756ce7030b6fe...
🔑 Creating API token 'jenkins-api-token'...
✅ API Token created successfully!

🎉 Success! API Token created:
Username: cursor
Token: 1143af6c5ad8c897c0adf01be489b26499
Jenkins URL: http://localhost:8080

🧪 Testing API token...
✅ Token test successful!

📋 Usage Examples:
curl -u cursor:1143af6c5ad8c897c0adf01be489b26499 http://localhost:8080/api/json
curl -u cursor:1143af6c5ad8c897c0adf01be489b26499 http://localhost:8080/job/k8s-cluster-deploy/api/json
```

### Environment File Export
When using `--save-to-file`, the script creates a file with:
```bash
JENKINS_USERNAME=cursor
JENKINS_API_TOKEN=1143af6c5ad8c897c0adf01be489b26499
JENKINS_URL=http://localhost:8080
```

## 🔗 Integration Examples

### CI/CD Pipeline Integration
```yaml
# GitHub Actions example
- name: Create Jenkins API Token
  run: |
    ./scripts/jenkins/create_api_token.sh \
      -u ${{ secrets.JENKINS_USERNAME }} \
      -p ${{ secrets.JENKINS_PASSWORD }} \
      --test \
      --save-to-file .env
```

### Docker Integration
```dockerfile
# Dockerfile example
COPY scripts/jenkins/ /opt/scripts/jenkins/
RUN chmod +x /opt/scripts/jenkins/*.sh
RUN pip3 install requests

# Usage in container
CMD ["/opt/scripts/jenkins/create_api_token.sh", "-u", "admin", "-p", "password"]
```

### Kubernetes Integration
```yaml
# Kubernetes Job example
apiVersion: batch/v1
kind: Job
metadata:
  name: jenkins-token-creator
spec:
  template:
    spec:
      containers:
      - name: token-creator
        image: python:3.9-slim
        command: ["/opt/scripts/jenkins/create_api_token.sh"]
        args: ["-u", "$(JENKINS_USERNAME)", "-p", "$(JENKINS_PASSWORD)"]
        env:
        - name: JENKINS_USERNAME
          valueFrom:
            secretKeyRef:
              name: jenkins-secrets
              key: username
        - name: JENKINS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: jenkins-secrets
              key: password
```

## 🧪 Testing

### Manual Testing
```bash
# Test with your Jenkins instance
./scripts/jenkins/create_api_token.sh \
  -u your-username \
  -p your-password \
  --test
```

### Automated Testing
```bash
# Test token functionality
TOKEN=$(./scripts/jenkins/create_api_token.sh -u cursor -p "P8p8c%4az0" | grep "Token:" | cut -d' ' -f2)
curl -u cursor:$TOKEN http://localhost:8080/api/json
```

## 🐛 Troubleshooting

### Common Issues

#### 1. CSRF Token Errors
```
❌ Failed to get crumb: 403
```
**Solution:** Verify Jenkins URL and credentials

#### 2. Network Timeout
```
❌ Network error getting crumb: timeout
```
**Solution:** Check network connectivity and Jenkins availability

#### 3. Missing Dependencies
```
❌ Python 3 is not installed
```
**Solution:** Install Python 3.6+ on your system

#### 4. Permission Denied
```
❌ Permission denied: ./create_api_token.sh
```
**Solution:** Make script executable: `chmod +x scripts/jenkins/create_api_token.sh`

### Debug Mode
For detailed debugging, run the Python script directly:
```bash
python3 -u scripts/jenkins/create_api_token.py -u username -p password
```

## 📈 Version History

### v1.1.1 (Current)
- ✅ Added comprehensive error handling
- ✅ Added token testing functionality
- ✅ Added environment file export
- ✅ Added dependency checking
- ✅ Added shell script wrapper
- ✅ Added comprehensive documentation

### v1.0.0
- ✅ Initial implementation
- ✅ Basic token creation
- ✅ CSRF handling

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the main LICENSE file for details.

## 🙏 Acknowledgments

- Jenkins community for excellent API documentation
- Python requests library for HTTP communication
- Open source community for best practices

---

**🎉 Happy Jenkins API Token Creation!**
