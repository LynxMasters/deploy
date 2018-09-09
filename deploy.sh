#!/usr/bin/env bash
# Deployment with zero downtime
# By default keeps 2 last deployments in KEEP_DEPLOYMENTS_DIR and current deployment

# Project domain
PROJECT_NAME=lynxmasters.com
# Project directory
PROJECT_DIR=/home/lynxmasters/lynxmasters.com

# Deployments directory
KEEP_DEPLOYMENTS_DIR=/home/lynxmasters/deployment_history
KEEP_DEPLOYMENTS=2

DEPLOY_DIR_NAME=$(date +'%d%m%Y_%H%M%S')
DEPLOY_DIR_PROJECT=${KEEP_DEPLOYMENTS_DIR}/${PROJECT_NAME}
DEPLOY_DIR=${DEPLOY_DIR_PROJECT}/${DEPLOY_DIR_NAME}

echo "Initialize deployment directory '"${DEPLOY_DIR}"'"
[ -d ${DEPLOY_DIR} ] || mkdir -p ${DEPLOY_DIR}

echo "Copying '"${PROJECT_DIR}/"' to '"${DEPLOY_DIR}"'"
rsync -a $PROJECT_DIR/ $DEPLOY_DIR

echo "Execute commands in deployment directory"
cd ${DEPLOY_DIR}

# Application Build
echo "Building Lynxmasters.com....."
echo "Create temporary image folder"
mkdir ./tmp
echo "Backing up Uploads"
cp -r ./lynxmasters-ui/dist/static/uploads ./tmp
cd lynxmasters-ui
git pull
echo "Building Lynxmasters UI...."
npm install --production
npm run build
mkdir -p ./dist/static/uploads
cd ..
echo "Put images back"
cp -r ./tmp ./lynxmasters-ui/dist/static/uploads
rm -r ./tmp

echo "Checking for SendGrid env...."
if [ ! -f ./lynxmasters-api/config/sendgrid.env ];
then
    echo "SendGrid API keys not found!"
    echo "Copying SendGrid env to config directory"
    cp sendgrid.env ./lynxmasters-api/config/
else
    echo "SendGrid env exists."
    echo "Stepping into API directory...."
fi

cd lynxmasters-api
git pull
echo "Building API"
cp example.env .env
npm install --production
echo "Starting API"
forever stopall
forever start ./bin/www


# Atomic, zero downtime
echo "Update symlink '"${DEPLOY_DIR}"' to '"${PROJECT_DIR}.tmp"'"
ln -s $DEPLOY_DIR ${PROJECT_DIR}.tmp

# Remove current project directory if not symlink
if [ ! -h $PROJECT_DIR ]; then
  rm -rf $PROJECT_DIR
fi

echo "Update symlink '"${DEPLOY_DIR}.tmp"' to '"${PROJECT_DIR}"'"
mv -Tf $PROJECT_DIR.tmp $PROJECT_DIR

echo "Clear old deployments in '"${DEPLOY_DIR_PROJECT}" keep last '"${KEEP_DEPLOYMENTS}"'"
cd ${DEPLOY_DIR_PROJECT}
rm -rf $(ls ${DEPLOY_DIR_PROJECT} -t | grep -v ${DEPLOY_DIR_NAME} | tail -n +$((KEEP_DEPLOYMENTS+1)))