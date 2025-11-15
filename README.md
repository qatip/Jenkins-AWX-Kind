# Jenkins-AWX-Kind

# Jenkins/AWX Lab

## 1. Create GitHub repositories
1. Create **two public GitHub repos**:  
   - `jenkinsdemo`  
   - `awxdemo`
2. Clone these empty repos to your working machine.

## 2. Clone the Jenkins–AWX–Kind project
3. Clone the repo:  
   ```bash
   git clone https://github.com/qatip/Jenkins-AWX-Kind.git
   ```
4. Open it in VS Code.
5. Create a local SSH pub/priv key:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/azure_automation_rsa -C "azure_automation_key"
   ```

## 3. Bootstrap Azure Storage Account (Terraform Remote Backend)
6. Move into the `bootstrap` directory.
7. Update `terraform.tfvars` with your Azure subscription ID.
8. Run:
   ```bash
   az login
   terraform init
   terraform apply
   ```
9. Note the generated **storage account name**.

## 4. Update Terraform files
10. Update `main.tf` (root module) with the storage account name.  
11. Update `terraform.tf` (root module) with your subscription ID.

12. Update the following in `/jenkins_repo_files/terraform_vm`:
   - `main.tf` → storage account name
   - `terraform.tf` → subscription ID

## 5. Deploy Jenkins and AWX VMs
13. Move back to the repo root and run:
   ```bash
   terraform init
   terraform apply
   ```
14. Note the public IPs for:
   - VM1 → Jenkins
   - VM2 → AWX

15. Retrieve Jenkins initial admin password (wait until Jenkins finishes install).

## 6. Create Azure Service Principal
16. Run:
   ```bash
   az ad sp create-for-rbac --name "jenkawxs-rfgt" --role Contributor --scopes /subscriptions/<subscription_id>
   ```
17. Record output values.

## 7. Configure Jenkins
### Log in
18. Browse to `http://<JenkinsIP>:8080`
19. Login with the initial admin password.
20. Install suggested plugins.
21. Continue as admin → Skip → **Not now**.

### Add credentials
22. Add the following as **Secret Text** credentials.

23. Add your public key as a **Secret File**:
   - Name: `vm-pubkey-file`
   - File: `azure_automation_rsa.pub`

## 8. Create AWX Token
24. Visit:  
   `http://<AWX-IP>:30080`
25. Login: **admin / ChangeMe123!**
26. Create token with Write scope.
27. Add token to Jenkins as `awx_api_token`.

## 9. Update JenkinsAWX file
28. Update IP + port references.
29. Update repo URLs.

## 10. Populate Git Repositories
30. Copy `jenkinsdemo_repo_files` → push to GitHub.
31. Copy `awxdemo_repo_files` → push to GitHub.

## 11. Configure AWX
32. Add **demo** project.
33. Add Azure SSH credential.
34. Create **DynamicHosts** inventory.
35. Create Job Templates:
   - Deploy NGINX Website
   - Remove NGINX Website

## 12. Update JenkinsAWX IDs
37. Update inventory ID.
38. Update job template ID.

## 13. Create Jenkins Pipelines
39. Create 4 pipeline jobs:
   - PlanPipeline  
   - ApplyPipeline  
   - DestroyPipeline  
   - AWXPipeline  

## 14. Execute Jenkins Pipelines
40. Run them in order.  
41. Verify results.

## 15. Test AWX automation
42. Confirm Deploy NGINX Website runs.
43. Browse to VM3 website.
44. Run Remove NGINX Website.

## 16. Clean Up
45. Run JenkinsDestroy.
46. Confirm site removed.
47. Destroy Terraform resources.
48. Destroy bootstrap backend.

**All resources should now be removed.**
