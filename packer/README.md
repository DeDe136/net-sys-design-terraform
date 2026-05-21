# 🚀 Web Portal Custom AMI Build

This directory contains Packer configuration to build a custom Amazon Linux 2 AMI with Nginx pre-installed for faster Auto Scaling Group (ASG) EC2 deployment.

## 📋 Problem Solved

When ASG terminates and recreates EC2 instances due to resource constraints (e.g., vCPU limits), instances using base AMI with user_data may fail health checks if:
- user_data takes too long to execute
- yum install fails
- Nginx fails to start properly

**Custom AMI Solution**: Nginx is already installed in the image, so EC2 starts healthy immediately.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Packer Build Process                                        │
├─────────────────────────────────────────────────────────────┤
│ 1. Start Amazon Linux 2 base instance                       │
│ 2. Run provisioners:                                        │
│    - Update system packages                                 │
│    - Install Nginx                                          │
│    - Copy index.html + web-portal.conf                      │
│    - Enable Nginx service                                   │
│ 3. Create golden AMI (ami-xxxxxxxxx)                        │
└─────────────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────────────┐
│ Terraform - Launch Template uses Custom AMI                 │
├─────────────────────────────────────────────────────────────┤
│ image_id = var.web_portal_ami_id  ← Custom AMI             │
└─────────────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────────────┐
│ Auto Scaling Group creates EC2                              │
├─────────────────────────────────────────────────────────────┤
│ - EC2 boots with Nginx already installed                    │
│ - user_data only starts service (3 seconds)                 │
│ - Health check passes immediately (180s grace)              │
│ - No more terminate/restart loops!                          │
└─────────────────────────────────────────────────────────────┘
```

## 🛠️ Prerequisites

### Install Packer
```bash
# macOS
brew install packer

# Linux
wget https://releases.hashicorp.com/packer/1.10.0/packer_1.10.0_linux_amd64.zip
unzip packer_1.10.0_linux_amd64.zip
sudo mv packer /usr/local/bin/

# Windows
choco install packer
# OR download from: https://www.packer.io/downloads
```

### AWS Credentials
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Default region (us-east-1)
```

## 📦 Files

| File | Purpose |
|------|---------|
| `web-portal.pkr.hcl` | Packer build configuration |
| `index.html` | Web portal landing page |
| `web-portal.conf` | Nginx server configuration |
| `build.sh` | Build script with pre-flight checks |

## 🚀 Quick Start

### Step 1: Build Custom AMI

```bash
cd packer/
bash build.sh
# OR specify region:
bash build.sh us-west-2
```

**Output will show:**
```
... build complete ...
amazon-ebs.web_portal: AMI: ami-0123456789abcdef0
```

### Step 2: Note the AMI ID
```bash
# Save the AMI ID (e.g., ami-0123456789abcdef0)
# Or query it:
aws ec2 describe-images --region us-east-1 --owners self --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text
```

### Step 3: Update Terraform Variables

Edit `environments/production/terraform.tfvars`:
```hcl
web_portal_ami_id = "ami-0123456789abcdef0"
```

Or add to `terraform.tfvars`:
```hcl
web_portal_ami_id = "ami-0123456789abcdef0"
erp_ami_id        = ""  # Optional for ERP/CRM
```

### Step 4: Deploy

```bash
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

## 🔄 How It Works

### Custom AMI Path (Recommended)
```
Launch Template image_id = custom AMI (ami-xxxxxxxxx)
                ↓
         EC2 boots quickly (Nginx pre-installed)
                ↓
       user_data: systemctl start nginx (3 seconds)
                ↓
    ALB health check passes (180s grace period)
                ↓
         ✅ Instance healthy
```

### Base Image Fallback
If `web_portal_ami_id` is empty, Terraform falls back to:
```
Launch Template image_id = var.ami
                ↓
    user_data: yum install nginx (60+ seconds)
                ↓
    ALB health check waits (600s grace period)
                ↓
   ✅ Instance healthy (if no errors)
```

## 📊 Performance Comparison

| Metric | Base AMI + user_data | Custom AMI |
|--------|----------------------|-----------|
| EC2 startup | ~2 min | ~1 min |
| Nginx install | 30-60s | 0s (pre-installed) |
| Health check grace | 600s (10 min) | 180s (3 min) |
| **Total to healthy** | **~10 min** | **~3.5 min** |

## 🔍 Verify AMI

```bash
# List custom AMIs
aws ec2 describe-images --region us-east-1 --owners self \
  --query 'Images[?contains(Name, `prod-web-portal`)].{ID:ImageId,Created:CreationDate,Name:Name}' \
  --output table

# Check AMI details
aws ec2 describe-images --region us-east-1 \
  --image-ids ami-0123456789abcdef0 --output table
```

## 🐛 Troubleshooting

### Packer Build Fails
```bash
# Check Packer syntax
packer fmt web-portal.pkr.hcl
packer validate -var="aws_region=us-east-1" web-portal.pkr.hcl

# Enable debug mode
PACKER_LOG=1 packer build web-portal.pkr.hcl
```

### Nginx Not Running After AMI Boot
```bash
# SSH into instance and check
ssh ec2-user@<instance-ip>
systemctl status nginx
tail -f /var/log/nginx/error.log
```

### Still Getting Health Check Failures
1. ✅ Confirm `web_portal_ami_id` variable is set in Terraform
2. ✅ Check ALB target group → Targets → Description (look for errors)
3. ✅ Verify security group allows ALB → EC2 on port 80
4. ✅ Check `/health` endpoint: `curl localhost/health`

## 🧹 Cleanup

### Delete Custom AMI (optional)
```bash
# Find AMI ID
AMI_ID=$(aws ec2 describe-images --region us-east-1 --owners self \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)

# Deregister AMI
aws ec2 deregister-image --region us-east-1 --image-id $AMI_ID

# Delete snapshots
aws ec2 describe-snapshots --region us-east-1 --owner-ids self \
  --query 'Snapshots[?Description==`*prod-web-portal*`].SnapshotId' \
  --output text | xargs -I {} aws ec2 delete-snapshot --region us-east-1 --snapshot-id {}
```

## 📚 References

- [Packer Documentation](https://www.packer.io/docs)
- [AWS EC2 AMI Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## ❓ FAQ

**Q: Do I need to rebuild the AMI every time I change Nginx config?**  
A: Yes, if you want the config baked into the image. Or keep config in user_data for flexibility.

**Q: Can I use this for ERP/CRM instances too?**  
A: Yes! Copy `web-portal.pkr.hcl` → `erp-crm.pkr.hcl`, customize, and set `erp_ami_id` variable.

**Q: How often should I rebuild the AMI?**  
A: Rebuild monthly or when OS patches/Nginx updates are needed.

---

**Status**: ✅ Ready for production use  
**Last Updated**: May 2026
