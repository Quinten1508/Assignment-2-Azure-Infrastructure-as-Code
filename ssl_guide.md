# SSL Configuration Guide for Azure Application Gateway

This guide walks through the process of configuring HTTPS with Let's Encrypt certificates on an Azure Application Gateway.

## Prerequisites
- Active Azure subscription
- Application Gateway already deployed and functioning with HTTP
- Let's Encrypt certificate obtained (using certbot)
- WSL or Linux environment with OpenSSL installed

## Step 1: Convert Let's Encrypt Certificates to PFX Format

In your WSL/Linux environment:

```bash
# Replace with your domain name path
sudo openssl pkcs12 -export -out certificate.pfx -inkey /etc/letsencrypt/live/iac.quinten-de-meyer.be/privkey.pem -in /etc/letsencrypt/live/iac.quinten-de-meyer.be/fullchain.pem
```

When prompted, enter and remember an export password. You'll need this later.

## Step 2: Copy Certificate to Windows (if using WSL)

```bash
cp ~/certificate.pfx /mnt/c/temp/
```

## Step 3: Create a Front-End Port for HTTPS (443)

```powershell
az network application-gateway frontend-port create --port 443 --gateway-name appgw-qdm-flask --name httpsPort --resource-group rg-qdm-flask-crud
```

## Step 4: Add SSL Certificate to Application Gateway

```powershell
az network application-gateway ssl-cert create --gateway-name appgw-qdm-flask --name iacCertificate --resource-group rg-qdm-flask-crud --cert-file C:\temp\certificate.pfx --cert-password "YourPasswordHere"
```

Replace `YourPasswordHere` with the export password you created in Step 1.

## Step 5: Create HTTPS Listener

```powershell
az network application-gateway http-listener create --name httpsListener --frontend-ip appGatewayFrontendIP --frontend-port httpsPort --resource-group rg-qdm-flask-crud --gateway-name appgw-qdm-flask --ssl-cert iacCertificate --host-name iac.quinten-de-meyer.be
```

## Step 6: Create Routing Rule for HTTPS Traffic

```powershell
az network application-gateway rule create --gateway-name appgw-qdm-flask --name httpsRule --resource-group rg-qdm-flask-crud --http-listener httpsListener --rule-type Basic --address-pool flaskCrudBackendPool --http-settings flaskCrudHttpSettings --priority 100
```

## Certificate Renewal Process

Let's Encrypt certificates are valid for 90 days. To renew:

1. Use certbot to obtain a new certificate
2. Repeat steps 1-4 of this guide
3. Update the SSL certificate in Application Gateway with the same name to replace the old one

```powershell
az network application-gateway ssl-cert update --gateway-name appgw-qdm-flask --name iacCertificate --resource-group rg-qdm-flask-crud --cert-file C:\temp\certificate.pfx --cert-password "YourPasswordHere"
``` 