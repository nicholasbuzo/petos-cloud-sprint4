#!/bin/bash

# Variáveis Gerais
RESOURCE_GROUP_NAME="rg-petos"
LOCATION="chilecentral" # ou a região que seu Azure for Students permite - ex: eastus, westus, etc

# Variáveis do Web App
WEBAPP_NAME="petos-561082"
APP_SERVICE_PLAN="plan-petos"
RUNTIME="JAVA|21-java21"
APP_INSIGHTS_NAME="ai-petos"

# Variáveis do Banco de Dados (Azure Database for PostgreSQL Flexible Server)
PG_SERVER_NAME="pg-petos-561082"
PG_DB_NAME="petosdb"

# Credenciais informadas no terminal, nunca versionadas:
#   export PG_ADMIN_USER="..."
#   export PG_ADMIN_PASSWORD="$(openssl rand -hex 24)"
#   echo "$PG_ADMIN_PASSWORD" # guarde este valor para o Variable Group
#   ./azure-setup.sh
: "${PG_ADMIN_USER:?Defina PG_ADMIN_USER antes de executar}"
: "${PG_ADMIN_PASSWORD:?Defina PG_ADMIN_PASSWORD antes de executar}"

echo "Criando resource group >>>"
az group create --name $RESOURCE_GROUP_NAME  --location "$LOCATION"

echo "Registrando provider Microsoft.DBforPostgreSQL >>>"
az provider register --namespace Microsoft.DBforPostgreSQL
echo "Aguardando registro do provider (pode levar 1-2 minutos) >>>"
while [ "$(az provider show --namespace Microsoft.DBforPostgreSQL --query registrationState -o tsv)" != "Registered" ]; do
  sleep 10
  echo "  ainda registrando..."
done

# 0.0.0.0 libera apenas os serviços da Azure; o IP de quem executa é liberado logo abaixo
echo "Criando servidor PostgreSQL Flexible Server >>>"
az postgres flexible-server create \
  --resource-group $RESOURCE_GROUP_NAME \
  --name $PG_SERVER_NAME \
  --location "$LOCATION" \
  --admin-user $PG_ADMIN_USER \
  --admin-password $PG_ADMIN_PASSWORD \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --storage-size 32 \
  --version 16 \
  --public-access 0.0.0.0 \
  --yes

echo "Liberando o IP atual para consultar o banco >>>"
MY_IP=$(curl -s https://api.ipify.org)
az postgres flexible-server firewall-rule create \
  --resource-group $RESOURCE_GROUP_NAME \
  --name $PG_SERVER_NAME \
  --rule-name AllowCurrentIp \
  --start-ip-address "$MY_IP" \
  --end-ip-address "$MY_IP"

echo "Criando banco de dados >>>"
az postgres flexible-server db create \
  --resource-group $RESOURCE_GROUP_NAME \
  --server-name $PG_SERVER_NAME \
  --name $PG_DB_NAME

echo "Criando app-insights >>>"
az monitor app-insights component create \
  --app $APP_INSIGHTS_NAME \
  --location "$LOCATION" \
  --resource-group $RESOURCE_GROUP_NAME \
  --application-type web

echo "Criando appservice plan >>>"
az appservice plan create \
  --name $APP_SERVICE_PLAN \
  --resource-group $RESOURCE_GROUP_NAME \
  --location "$LOCATION" \
  --sku B1 \
  --is-linux

echo "Criando webapp >>>"
az webapp create \
  --name $WEBAPP_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --plan $APP_SERVICE_PLAN \
  --runtime "$RUNTIME"

echo "Mantendo o Web App sempre ativo e somente em HTTPS >>>"
az webapp config set \
  --name $WEBAPP_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --always-on true
az webapp update \
  --name $WEBAPP_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --https-only true

# Recuperar a Connection String do Application Insights
CONNECTION_STRING=$(az monitor app-insights component show \
  --app $APP_INSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP_NAME \
  --query connectionString \
  --output tsv)

# Os dados sensíveis são aplicados pela pipeline de CD a partir do Variable Group "petos-secrets"
echo "Definindo configurações não sensíveis no web app >>>"
az webapp config appsettings set \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP_NAME" \
  --settings \
    PETOS_JWT_EXPIRATION_MINUTES="120" \
    SPRING_PROFILES_ACTIVE="prod" \
    APPLICATIONINSIGHTS_CONNECTION_STRING="$CONNECTION_STRING" \
    ApplicationInsightsAgent_EXTENSION_VERSION="~3" \
    XDT_MicrosoftApplicationInsights_Mode="Recommended" \
    XDT_MicrosoftApplicationInsights_PreemptSdk="1"

echo "Reiniciando Web App e conectando App Insights"
az webapp restart --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP_NAME

az monitor app-insights component connect-webapp \
  --app $APP_INSIGHTS_NAME \
  --web-app $WEBAPP_NAME \
  --resource-group $RESOURCE_GROUP_NAME

echo "Infraestrutura criada. O deploy é feito pelas pipelines do Azure DevOps."