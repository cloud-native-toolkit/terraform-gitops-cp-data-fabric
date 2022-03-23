#!/bin/sh

############################################################
# Login to Cloud pak for Data and get the token
############################################################
CPD_CLUSTER_HOST="https://ibm-nginx-svc"
USERNAME="${ENV_USERNAME}"
PASSWORD="${ENV_PASSWORD}"

if [ "${CPD_CLUSTER_HOST}" != "" ] && [ "${USERNAME}" != "" ] && [ "${PASSWORD}" != "" ]; then
  if ! CPD_TOKEN=$(
    curl -k -X POST \
      "${CPD_CLUSTER_HOST}"/icp4d-api/v1/authorize \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"username": "'"${USERNAME}"'","password":"'"${PASSWORD}"'"}' | jq -r '.token'
  ); then
    exit 1
  fi
fi

############################################################
#  Create Users in Cloud pak for Data
############################################################
CPD_USER1="dfengineer"
CPD_USER2="dfsteward"
CPD_USER3="dfscientist"

if [ "$CPD_CLUSTER_HOST" != "" ] && [ "$CPD_TOKEN" != "" ]; then
  EMAIL="${CPD_USER1}@in.ibm.com"
  if ! DFUSER1_RESPONSE=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST"/icp4d-api/v1/users \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"user_name":"'"$CPD_USER1"'","displayName":"'"$CPD_USER1"'","email":"'"${EMAIL}"'","password":"'"$CPD_USER1"'" , "user_roles": ["zen_data_engineer_role", "zen_developer_role", "zen_user_role"]}'
  ); then
    echo "Failed to Create dfuser1"
    exit 1
  fi
  echo "dfuser1 created"
  EMAIL="${CPD_USER2}@in.ibm.com"
  if ! DFUSER2_RESPONSE=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST"/icp4d-api/v1/users \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"user_name":"'"$CPD_USER2"'","displayName":"'"$CPD_USER2"'","email":"'"${EMAIL}"'","password":"'"$CPD_USER2"'" , "user_roles": ["wkc_data_quality_analyst_role", "wkc_data_steward_role", "zen_developer_role", "zen_user_role"]}'
  ); then
    echo "Failed to Create dfuser2"
    exit 1
  fi
  echo "dfuser2 created"
  EMAIL="${CPD_USER3}@in.ibm.com"
  if ! DFUSER3_RESPONSE=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST"/icp4d-api/v1/users \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"user_name":"'"$CPD_USER3"'","displayName":"'"$CPD_USER3"'","email":"'"${EMAIL}"'","password":"'"$CPD_USER3"'" , "user_roles": ["wkc_data_scientist_role", "zen_developer_role", "zen_user_role"]}'
  ); then
    echo "Failed to Create dfuser3"
    exit 1
  fi
  echo "dfuser3 created"
else
  echo "Please provide CPD_CLUSTER_HOST & CPD_TOKEN "
fi

############################################################
# Create Amazon S3 Platform connection in Cloud pak for Data
############################################################
BUCKET="${ENV_S3_BUCKET_ID}"
REGION="${ENV_S3_BUCKET_REGION}"
URL="${ENV_S3_BUCKET_URL}"
ACCESS_KEY="${ENV_AWS_ACCESS_KEY}"
SECRET_KEY="${ENV_AWS_SECRET_KEY}"


if [ "$CPD_CLUSTER_HOST" != "" ] && [ "$CPD_TOKEN" != "" ]; then
  if ! DS_RESPONSE=$(
    curl -k -X GET \
      "$CPD_CLUSTER_HOST"/v2/datasource_types \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json'
  ); then
    echo "Failed to get CPD datasource types"
    exit 1
  fi
  DATASOURCE_TYPE=$(echo "$DS_RESPONSE" | jq -r '.resources[] | select(.entity.name=="amazons3") | .metadata.asset_id')
  echo "ASSET_ID ---- $DATASOURCE_TYPE "

  if ! CAT_RESPONSE=$(
    curl -k -X GET \
      "$CPD_CLUSTER_HOST"/v2/catalogs \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json'
  ); then
    echo "Failed to get CPD Catalogs"
    exit 1
  fi
  CATALOG_ID=$(echo "$CAT_RESPONSE" | jq -r '.catalogs[] | select(.entity.name=="Platform assets catalog") | .metadata.guid')
  echo "GUID ---- $CATALOG_ID "
  CREATE_CONN_URL="$CPD_CLUSTER_HOST/v2/connections?test=true&catalog_id=$CATALOG_ID"
  echo "CREATE_CONN_URL --- $CREATE_CONN_URL"

  if ! AWS_CONNECTION=$(
    curl -k -X POST \
      "$CREATE_CONN_URL" \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"datasource_type":"'"$DATASOURCE_TYPE"'","flags":[],"name":"aws-s3-conn","origin_country":"us","properties":{"bucket":"'"$BUCKET"'","region":"'"$REGION"'","url":"'"$URL"'","access_key":"'"$ACCESS_KEY"'","secret_key":"'"$SECRET_KEY"'"}}'
  ); then
    echo "Failed to create AWS connection"
    exit 1
  fi
  AWS_CONN_NAME=$(echo "$AWS_CONNECTION" | jq -r '. | select(.entity.name=="aws-s3-conn") | .entity.name')
  echo "AWS Connection with name ""$AWS_CONN_NAME "" created"
  CONNECTION_ID=$(echo "$AWS_CONNECTION" | jq -r '. | select(.metadata.asset_id=="aws-s3-conn") | .metadata.asset_id')

  if ! ADD_DS_DV=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST"/icp4data-databases/dv/zen/dvapiserver/v1/datasource_connection_v2 \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"catalog_id":"'"$CATALOG_ID"'","connection_id":"'"$CONNECTION_ID"'"}'
  ); then
    echo "Failed to Add Data Source to DV"
    exit 1
  fi
  echo "Data Source to DV Added"

else
  echo "Please provide CPD_CLUSTER_HOST & CPD_TOKEN "
fi

############################################################
# Create Analytics Project in Cloud pak for Data
############################################################
ANALYTICS_PROJECT_NAME="datafab-autoai-project"

if [ "$CPD_CLUSTER_HOST" != "" ] && [ "$CPD_TOKEN" != "" ]; then
  UNIQUE_ID=$(openssl rand -hex 2)
  NAME="$ANALYTICS_PROJECT_NAME$UNIQUE_ID"
  if ! PROJECT_LOCATION=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST"/transactional/v2/projects \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"name":"'"$NAME"'","description":"This is a project for AutoAI for Data Fabric","public":false,"storage":{"type":"assetfiles","guid":"d0e410a0-b358-42fc-b402-dba83316413a"}}' | jq -r '.location'
  ); then
    echo "Failed to Create Analytics Project"
    exit 1
  fi
  echo "Analytics Project created"
  if ! DFUSER1_ID=$(
    curl -k -X GET \
      "$CPD_CLUSTER_HOST/icp4d-api/v1/users/$CPD_USER1" \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' | jq -r '.UserInfo.uid'
  ); then
    echo "Failed to get dfuser1 details"
    exit 1
  fi
  echo "DFUSER1_ID $DFUSER1_ID"
  if ! DFUSER2_ID=$(
    curl -k -X GET \
      "$CPD_CLUSTER_HOST/icp4d-api/v1/users/$CPD_USER2" \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' | jq -r '.UserInfo.uid'
  ); then
    echo "Failed to get dfuser2 details"
    exit 1
  fi
  echo "DFUSER2_ID $DFUSER2_ID"
  if ! DFUSER3_ID=$(
    curl -k -X GET \
      "$CPD_CLUSTER_HOST/icp4d-api/v1/users/$CPD_USER3" \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' | jq -r '.UserInfo.uid'
  ); then
    echo "Failed to get dfuser3 details"
    exit 1
  fi
  echo "DFUSER3_ID $DFUSER3_ID"

  PROJECT_URL="$CPD_CLUSTER_HOST$PROJECT_LOCATION/members"
  echo "PROJECT_URL $PROJECT_URL"
  if ! ADD_COLLABRATORS=$(
    curl -k -X POST \
      "$PROJECT_URL" \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"members":[{"id":"'"$DFUSER1_ID"'","state":"ACTIVE","type":"user","user_name":"'"$CPD_USER1"'","role":"editor"},{"id":"'"$DFUSER2_ID"'","state":"ACTIVE","type":"user","user_name":"'"$CPD_USER2"'","role":"editor"},{"id":"'"$DFUSER3_ID"'","state":"ACTIVE","type":"user","user_name":"'"$CPD_USER3"'","role":"editor"}]}'
  ); then
    echo "Failed to ADD COLLABRATORS"
    exit 1
  fi
  echo "COLLABRATORS Added to the Project"
  #Get DV instance ID
  if ! SVC_INSTANCE_LIST=$(
    curl -k -X GET \
      "$CPD_CLUSTER_HOST"/zen-data/v3/service_instances \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json'
  ); then
    echo "Failed to Get DV instance ID"
    exit 1
  fi
  DV_INST_ID=$(echo "$SVC_INSTANCE_LIST" | jq -r '.service_instances[] | select(.addon_type=="dv") | .id')
  echo "DV instance ID- $DV_INST_ID"
  #Assign dv view to above created analytics project
  PROJECT_ID=${PROJECT_LOCATION##*/}
  DV_INST_STR="dv-$DV_INST_ID"
  if ! ASSIGN_VIRTUALISED_OBJ=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST"/icp4data-databases/dv/zen/dvapiserver/v1/integration/cp4d/project/assign \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -H 'X-DB-Profile: '"$DV_INST_STR"'' \
      -d '{"project_id":"'"$PROJECT_ID"'","vts":["ADMIN.CUSTOMER360"]}'
  ); then
    echo "Failed to Assign virtualised obj"
    exit 1
  fi
  echo "Assign virtualised obj initiated"
else
  echo "Please provide CPD_CLUSTER_HOST & CPD_TOKEN "
fi

############################################################
# Virtualize files from DV
############################################################
if [ "$CPD_CLUSTER_HOST" != "" ] && [ "$CPD_TOKEN" != "" ]; then
  #Virtualize file from s3
  if ! VIRTUALIZE_FILE_S3=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST"/icp4data-databases/dv/zen/dvapiserver/v1/virtualize/cloud_object_storages \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"url":"s3a://"'"$BUCKET_NAME"'"/dvcustomer","virtual_schema":"ADMIN","virtual_name":"dvcustomer","virtual_table_def":[{"column_name":"Customer_ID","column_type":"VARCHAR(3)"},{"column_name":"Name","column_type":"VARCHAR(19)"},{"column_name":"Address","column_type":"VARCHAR(24)"},{"column_name":"City","column_type":"VARCHAR(11)"},{"column_name":"State","column_type":"VARCHAR(16)"},{"column_name":"County","column_type":"VARCHAR(5)"},{"column_name":"Age","column_type":"INT"},{"column_name":"Birthdate","column_type":"VARCHAR(8)"},{"column_name":"Employer","column_type":"VARCHAR(21)"},{"column_name":"annual_income","column_type":"VARCHAR(8)"},{"column_name":"Gender","column_type":"VARCHAR(6)"},{"column_name":"email","column_type":"VARCHAR(34)"},{"column_name":"mobile","column_type":"BIGINT"},{"column_name":"pancard","column_type":"VARCHAR(10)"},{"column_name":"aadhaar_card","column_type":"VARCHAR(11)"},{"column_name":"Profession","column_type":"VARCHAR(24)"},{"column_name":"marital_status","column_type":"BOOLEAN"},{"column_name":"Children","column_type":"VARCHAR(1)"},{"column_name":"employed_yrs_x000D","column_type":"VARCHAR(102)"}],"is_replace":false,"options":"COLNAMES=true"}'
  ); then
    echo "Failed to Virtualize file from s3"
    exit 1
  fi
  echo "Virtualize file from s3 initiated"
  #Virtualize cibil_score table
  if ! VIRTUALIZE_CIBIL=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST"/icp4data-databases/dv/zen/dvapiserver/v1/virtualize/cloud_object_storages \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"url":"s3a://"'"$BUCKET_NAME"'"/dvcibil","virtual_schema":"ADMIN","virtual_name":"dvcibil","virtual_table_def":[{"column_name":"Customer_ID","column_type":"VARCHAR(3)"},{"column_name":"cibil_score","column_type":"VARCHAR(4)"}],"is_replace":false,"options":"COLNAMES=true"}'
  ); then
    echo "Failed to Virtualize cibil_score table"
    exit 1
  fi
  echo "Virtualize cibil_score table initiated"
else
  echo "Please provide CPD_CLUSTER_HOST & CPD_TOKEN "
fi

############################################################
# Create Join
############################################################
if [ "$CPD_CLUSTER_HOST" != "" ] && [ "$CPD_TOKEN" != "" ]; then
  #Get DV instance ID
  if ! SVC_INSTANCE_LIST=$(
    curl -k -X GET \
      "$CPD_CLUSTER_HOST"/zen-data/v3/service_instances \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json'
  ); then
    echo "Failed to Get DV instance ID"
    exit 1
  fi
  DV_INST_ID=$(echo "$SVC_INSTANCE_LIST" | jq -r '.service_instances[] | select(.addon_type=="dv") | .id')
  echo "DV instance ID- $DV_INST_ID"
  #Create Join
  if ! CREATE_JOIN=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST"/icp4data-databases/dv/zen/dvapiserver/v1/views/CUSTOMER360 \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"schemaName":"ADMIN","tables":[{"name":"dvcibil","schemaName":"ADMIN","selectedColumns":[{"oldName":"cibil_score","newName":"cibil_score"}]},{"name":"dvcustomer","schemaName":"ADMIN","selectedColumns":[{"oldName":"Customer_ID","newName":"Customer_ID"},{"oldName":"Name","newName":"Name"},{"oldName":"Address","newName":"Address"},{"oldName":"City","newName":"City"},{"oldName":"State","newName":"State"},{"oldName":"County","newName":"County"},{"oldName":"Age","newName":"Age"},{"oldName":"Birthdate","newName":"Birthdate"},{"oldName":"Employer","newName":"Employer"},{"oldName":"annual_income","newName":"annual_income"},{"oldName":"Gender","newName":"Gender"},{"oldName":"email","newName":"email"},{"oldName":"mobile","newName":"mobile"},{"oldName":"Profession","newName":"Profession"},{"oldName":"marital_status","newName":"marital_status"},{"oldName":"Children","newName":"Children"},{"oldName":"employed_yrs_x000D","newName":"employed_yrs_x000D"}]}],"serviceInstanceId":"'"$DV_INST_ID"'","joinKeys":[{"name":"Customer_ID_Customer_ID","sourceTable":{"tableName":"dvcibil","schemaName":"ADMIN","key":"Customer_ID"},"targetTable":{"tableName":"dvcustomer","schemaName":"ADMIN","key":"Customer_ID"}}]}'
  ); then
    echo "Failed to Create Join"
    exit 1
  fi
  echo "Create Join initiated"
else
  echo "Please provide CPD_CLUSTER_HOST & CPD_TOKEN "
fi

############################################################
# Create Category, Classification, Business Term,
# Reference Data, Data Class, Data Protection Rule
############################################################
if [ "$CPD_CLUSTER_HOST" != "" ] && [ "$CPD_TOKEN" != "" ]; then
  UNIQUE_ID=$(openssl rand -hex 2)
  NAME="Data Fabric Category$UNIQUE_ID"
  #Create Category
  if ! CREATE_CATEGORY=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST"/v3/categories \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"name":"'"$NAME"'","short_description":"","long_description":"This is for Data Fabric"}'
  ); then
    echo "Failed to Create Category "
    exit 1
  fi
  echo "Create Category  Completed"
  CATEGORY_ID=$(echo "$CREATE_CATEGORY" | jq -r '.resources[] | select(.entity_type=="category") | .artifact_id')
  #Create Classification
  NAME="Data Fabric Classification$UNIQUE_ID"
  if ! CREATE_CLASSIFICATION=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST"/v3/classifications?skip_workflow_if_possible=true \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"name":"'"$NAME"'","long_description":"This is a Data Fabric classification","parent_category":{"id":"'"$CATEGORY_ID"'","name":"Data Fabric Category","context":[]}}'
  ); then
    echo "Failed to Create Classification"
    exit 1
  fi
  echo "Create Classification Completed"
  CLASSIFICATION_ID=$(echo "$CREATE_CLASSIFICATION" | jq -r '.resources[] | select(.entity_type=="classification") | .artifact_id')
  #Create Business Term
  NAME="Data Fabric Business Term$UNIQUE_ID"
  if ! CREATE_BUSINESS_TERM=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST"/v3/glossary_terms?skip_workflow_if_possible=true \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '[{"name":"'"$NAME"'","long_description":"This is a Data Fabric Business Term","parent_category":{"id":"'"$CATEGORY_ID"'","name":"Data Fabric Category","context":[]}}]'
  ); then
    echo "Failed to Create Business Term"
    exit 1
  fi
  echo "Create Business Term Completed"
  BUSINESS_TERM_ID=$(echo "$CREATE_BUSINESS_TERM" | jq -r '.resources[] | select(.entity_type=="glossary_term") | .artifact_id')
  #Create Reference Data Set
  NAME="Data Fabric data$UNIQUE_ID"
  if ! CREATE_REF_DATASET=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST"/v3/reference_data?skip_workflow_if_possible=true \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"name":"'"$NAME"'","type":"Text","parent_category":{"id":"'"$CATEGORY_ID"'","name":"Data Fabric Category","context":[]},"rds_values":[{"code":"SWZ","value":"Eswatini","parent":null,"description":"The Kingdom of Eswatini"}],"terms":[{"id":"'"$BUSINESS_TERM_ID"'"}]}'
  ); then
    echo "Failed to Create Reference Data Set"
    exit 1
  fi
  echo "Create Reference Data Set Completed"
  REF_FILE_ID=$(echo "$CREATE_REF_DATASET" | jq -r '.resources[] | select(.entity_type=="reference_data") | .artifact_id')
  #Create Data Class
  NAME="Data Fabric data$UNIQUE_ID"
  if ! CREATE_DATA_CLASS=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST"/v3/data_classes?skip_workflow_if_possible=true \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"name":"'"$NAME"'","long_description":"This is a Data Fabric data class","data_class_type":"ReferenceDataSet","case_sensitive":false,"allow_substring_match":false,"valid_value_reference_file":"'"$REF_FILE_ID"'","squeeze_consecutive_white_spaces":false,"enabled":true,"applicable_for":"structured_data_only","parent_category":{"id":"'"$CATEGORY_ID"'","name":"Data Fabric Category","context":[]},"terms":[{"id":"'"$BUSINESS_TERM_ID"'"}]}'
  ); then
    echo "Failed to Create Data Class"
    exit 1
  fi
  echo "Create Data Class Completed"
  DATA_CLASS_ID=$(echo "$CREATE_DATA_CLASS" | jq -r '.resources[] | select(.entity_type=="data_class") | .global_id')
  DSYMBOL="$"
  VALUE="${DSYMBOL}$DATA_CLASS_ID"
  #Create Data Protection Rule
  NAME="Data Fabric rule$UNIQUE_ID"
  if ! CREATE_CLASSIFICATION=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST"/v3/enforcement/rules \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"description":"this is a Data Fabric rule","name":"'"$NAME"'","governance_type_id":"Access","trigger":["$Asset.InferredClassification","CONTAINS",["'"${VALUE}"'"]],"action":{"name":"Transform","subaction":{"name":"redactDataClasses","parameters":[{"name":"dataclass_ids","value":["'"$DATA_CLASS_ID"'"]}]}},"state":"active"}'
  ); then
    echo "Failed to Create Data Protection Rule"
    exit 1
  fi
  echo "Create Data Protection Rule Completed"
else
  echo "Please provide CPD_CLUSTER_HOST & CPD_TOKEN "
fi

############################################################
# Add Connection to Catalog, Add Connected asset to Catalog,
# Add users to Catalog
############################################################
if [ "$CPD_CLUSTER_HOST" != "" ] && [ "$CPD_TOKEN" != "" ]; then
  UNIQUE_ID=$(openssl rand -hex 2)
  NAME="DataFabricCatalog$UNIQUE_ID"
  #Create Catalog
  if ! CATALOG_ID=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST"/v2/catalogs \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"name":"'"$NAME"'","description":"This Catalog of for Data Fabric","generator":"admin@ibm.com","is_governed":true}' | jq -r '.metadata.guid'
  ); then
    echo "Failed to Create Catalog  "
    exit 1
  fi
  echo "Create Catalog   Completed"
  if ! DFUSER1_ID=$(
    curl -k -X GET \
      "$CPD_CLUSTER_HOST/icp4d-api/v1/users/$CPD_USER1" \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' | jq -r '.UserInfo.uid'
  ); then
    echo "Failed to get dfuser1 details"
    exit 1
  fi
  echo "DFUSER1_ID $DFUSER1_ID"
  if ! DFUSER2_ID=$(
    curl -k -X GET \
      "$CPD_CLUSTER_HOST/icp4d-api/v1/users/$CPD_USER2" \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' | jq -r '.UserInfo.uid'
  ); then
    echo "Failed to get dfuser2 details"
    exit 1
  fi
  echo "DFUSER2_ID $DFUSER2_ID"
  #Add Users to Catalog
  if ! ADD_USERS=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST/v2/catalogs/$CATALOG_ID/members" \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"members":[{"user_id":"'"$CPD_USER1"'","user_iam_id":"'"$DFUSER1_ID"'","access_group_id":null,"role":"editor","href":"string","create_time":"string"},{"user_id":"'"$CPD_USER1"'","user_iam_id":"'"$DFUSER1_ID"'","access_group_id":null,"role":"editor","href":"string","create_time":"string"}]}'
  ); then
    echo "Failed to Add Users to Catalog"
    exit 1
  fi
  echo "Add Users to Catalog Completed"
  # #Add Connection to Catalog
  # CREATE_CONN_URL="$CPD_CLUSTER_HOST/projects/api/connections-v2?test=true&catalog_id=b6079fda-25ab-4b2b-bebc-02a6135c5e71"
  # if ! ADD_CONN_CAT=$(curl -k -X POST  \
  #         "$CREATE_CONN_URL" \
  #         -H 'Authorization: Bearer '"$CPD_TOKEN"''\
  #         -H 'cache-control: no-cache' \
  #         -H 'content-type: application/json' \
  #         -d '{"ref_catalog_id":"c3fe634e-2680-4223-912c-7864a6303fac","ref_asset_id":"26192d4e-d7ca-469b-b31d-cb5accd9cf41"}'
  # );then
  #   echo "Failed to Add Connection to Catalog "
  #   exit 1
  # fi
  # echo "Add Connection to Catalog Completed"
  # #Add Connected Data Asset to Catalog
  #  if ! CREATE_REF_DATASET=$(curl -k -X POST  \
  #         "$CPD_CLUSTER_HOST"/data/catalogs/api/b6079fda-25ab-4b2b-bebc-02a6135c5e71/connection-asset \
  #         -H 'Authorization: Bearer '"$CPD_TOKEN"''\
  #         -H 'cache-control: no-cache' \
  #         -H 'content-type: application/json' \
  #         -d '{"metadata":{"name":"Customer.csv","description":"","tags":[],"assetType":"data_asset","originCountry":"none","dataFormat":"application/octet-stream","members":[],"privacy":0,"classification":""},"entity":{"data_asset":{"dataset":true,"mime_type":"text/csv","properties":[{"name":"bucket","value":"datafabric-v2"},{"name":"file_name","value":"dvcustomer/Customer.csv"},{"name":"first_line_header","value":"true"},{"name":"encoding","value":"UTF-8"},{"name":"invalid_data_handling","value":"fail"},{"name":"file_format","value":"csv"}],"columns":[{"name":"Customer_ID","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"Name","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"Address","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"City","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"State","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"County","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"Age","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"Birthdate","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"Employer","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"annual_income","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"Gender","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"email","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"mobile","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"pancard","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"aadhaar_card","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"Profession","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"marital_status","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"Children","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}},{"name":"employed_yrs","type":{"type":"varchar","length":1024,"scale":0,"nullable":true}}]}},"assetType":"data_asset","connection_id":"a0a08af4-91c9-4b5f-a9b4-93bd85b814ed","connection_path":"/datafabric-v2/dvcustomer/Customer.csv","is_partitioned":false,"assetTerms":{"name":"asset_terms","entity":{"list":[]}}}'
  # );then
  #   echo "Failed to Add Connected Data Asset to Catalog"
  #   exit 1
  # fi
  # echo "Add Connected Data Asset to Catalog Completed"

else
  echo "Please provide CPD_CLUSTER_HOST & CPD_TOKEN "
fi

############################################################
# Create Auto AI Experiment
# (Create Space, Create Pipeline, Create Data Asset,
# Create & Upload Attachment, Create Training and Deploy Model)
############################################################
if [ "$CPD_CLUSTER_HOST" != "" ] && [ "$CPD_TOKEN" != "" ]; then
  UNIQUE_ID=$(openssl rand -hex 1)
  NAME="Data Fabric$UNIQUE_ID"
  #Create Space
  if ! CREATE_SPACE=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST"/v2/spaces \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"name":"'"$NAME"'","description":"Data Fabric Auto AI Experiment"}'
  ); then
    echo "Failed to Create Space "
    exit 1
  fi
  sleep 5
  echo "Create Space  Completed $CREATE_SPACE"
  SPACE_ID=$(echo "$CREATE_SPACE" | jq -r '.metadata.id')
  echo "SPACE_ID*************$SPACE_ID"
  #Create Pipeline
  NAME="Data Fabric Credit Risk Prediction - AutoAI$UNIQUE_ID"
  if ! CREATE_PIPELINE=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST/ml/v4/pipelines?version=2020-08-01" \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"space_id":"'"$SPACE_ID"'","name":"'"$NAME"'","description":"","document":{"doc_type":"pipeline","version":"2.0","pipelines":[{"id":"autoai","runtime_ref":"hybrid","nodes":[{"id":"automl","type":"execution_node","parameters":{"stage_flag":true,"output_logs":true,"input_file_separator":",","optimization":{"learning_type":"binary","label":"Risk","max_num_daub_ensembles":1,"daub_include_only_estimators":["ExtraTreesClassifierEstimator","GradientBoostingClassifierEstimator","LGBMClassifierEstimator","LogisticRegressionEstimator","RandomForestClassifierEstimator","XGBClassifierEstimator","DecisionTreeClassifierEstimator"],"scorer_for_ranking":"roc_auc","compute_pipeline_notebooks_flag":true,"run_cognito_flag":true,"holdout_param":0.1}},"runtime_ref":"autoai","op":"kube"}]}],"runtimes":[{"id":"autoai","name":"auto_ai.kb","app_data":{"wml_data":{"hardware_spec":{"name":"L"}}},"version":"3.0.2"}],"primary_pipeline":"autoai"}}'
  ); then
    echo "Failed to Create Pipeline"
    exit 1
  fi
  sleep 5
  echo "Create Pipeline Completed"
  PIPELINE_ID=$(echo "$CREATE_PIPELINE" | jq -r '.metadata.id')
  echo "PIPELINE_ID*************$PIPELINE_ID"
  #Create Data Asset
  NAME="df_autoai_training_data$UNIQUE_ID"
  if ! CREATE_DATA_ASSET=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST/v2/assets?space_id=$SPACE_ID&version=2020-08-01" \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"metadata":{"name":"'"$NAME"'","description":"desc","asset_type":"data_asset","origin_country":"us","asset_category":"USER"},"entity":{"data_asset":{"mime_type":"text/csv"}}}'
  ); then
    echo "Failed to Create Data Asset"
    exit 1
  fi
  echo "Create Data Asset Completed"
  HREF=$(echo "$CREATE_DATA_ASSET" | jq -r '.href')
  ASSET_ID=$(echo "$CREATE_DATA_ASSET" | jq -r '.metadata.asset_id')
  ASSET_TYPE=$(echo "$CREATE_DATA_ASSET" | jq -r '.metadata.asset_type')

  echo "HREF ******************$HREF"
  echo "ASSET_ID***************$ASSET_ID"
  echo "ASSET_TYPE*************$ASSET_TYPE"

  #Create Attachment
  NAME="df_"$UNIQUE_ID"_credit_risk_training_light.csv"
  if ! CREATE_ATTACHMENT=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST/v2/assets/$ASSET_ID/attachments?space_id=$SPACE_ID&version=2020-08-01" \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"asset_type":"'"$ASSET_TYPE"'","name":"'"$NAME"'","mime":"text/csv"}'
  ); then
    echo "Failed to Create Attachment"
    exit 1
  fi
  sleep 2
  echo "Create Attachment Completed ***** $CREATE_ATTACHMENT"
  URL1_PATH=$(echo "$CREATE_ATTACHMENT" | jq -r '.url1')
  ATTACHMENT_ID=$(echo "$CREATE_ATTACHMENT" | jq -r '.attachment_id')
  echo "URL1_PATH --- $URL1_PATH"
  echo "ATTACHMENT_ID --- $ATTACHMENT_ID"
  #Upload CSV file
  if ! UPLOAD_CSV=$(
    curl -sk -X PUT \
      "$CPD_CLUSTER_HOST$URL1_PATH" \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'content-type: multipart/form-data' \
      -F 'file=@/df-scripts/credit_risk_training_light.csv'
  ); then
    echo "Failed to Upload CSV file ** $UPLOAD_CSV"
    exit 1
  fi
  echo "Upload CSV file Completed"

  #Check Status
  if ! CHECK_STATUS=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST/v2/assets/$ASSET_ID/attachments/$ATTACHMENT_ID/complete?space_id=$SPACE_ID&version=2020-08-01" \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json'
  ); then
    echo "Failed to Check Status"
    exit 1
  fi
  echo "Check Status Completed"

  #Create Training
  RANDOM_ID=$(openssl rand -hex 20)
  LOC_PATH="/spaces/"$SPACE_ID"/assets/auto_ml/auto_ml_curl."$RANDOM_ID"/wml_data"
  if ! CREATE_TRAINING=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST/ml/v4/trainings?version=2020-08-01" \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"space_id":"'"$SPACE_ID"'","training_data_references":[{"type":"'"$ASSET_TYPE"'","id":"credit_risk_training_light.csv","connection":{},"location":{"href":"'"$HREF"'"}}],"results_reference":{"type":"fs","id":"autoai_results","connection":{},"location":{"path":"'"$LOC_PATH"'"}},"tags":[{"value":"autoai"}],"pipeline":{"id":"'"$PIPELINE_ID"'"}}'

  ); then
    echo "Failed to Create Training -- $CREATE_TRAINING"
    exit 1
  fi
  echo "Create Training Completed - $CREATE_TRAINING"
  TRAINING_ID=$(echo "$CREATE_TRAINING" | jq -r '.metadata.id')
  echo "TRAINING_ID**********$TRAINING_ID"

  CHECK_TRAINING_STATUS="pending"

  while [ "$CHECK_TRAINING_STATUS" != "completed" ]; do
    #Check Training Status
    TRAINING_STATUS_API="$CPD_CLUSTER_HOST/ml/v4/trainings/$TRAINING_ID?space_id=$SPACE_ID&version=2020-08-01"
    echo "TRAINING_STATUS_API*****$TRAINING_STATUS_API"
    sleep 30
    if ! CHECK_TRAINING_STATUS=$(
      curl -sk -X GET \
        "$TRAINING_STATUS_API" \
        -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
        -H 'content-type: application/json' | jq -r '.entity.status.state'
    ); then
      echo "Failed to Check Training Status"
      exit 1
    fi
    echo "Check Training Status **** $CHECK_TRAINING_STATUS *******"
  done
  #Get Model Payload
  MODEL_PAYLOAD_API="$CPD_CLUSTER_HOST/v2/asset_files/auto_ml/auto_ml_curl.$RANDOM_ID/wml_data/$TRAINING_ID/assets/"$TRAINING_ID"_P1_global_output/resources/wml_model/request.json?space_id=$SPACE_ID"
  if ! MODEL_PAYLOAD=$(
    curl -sk -X GET \
      "$MODEL_PAYLOAD_API" \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'content-type: application/json'
  ); then
    echo "Failed to Get Model Payload --- $MODEL_PAYLOAD"
    exit 1
  fi
  echo "Get Model Payload Completed ----- $MODEL_PAYLOAD"

  #Create Model
  if ! CREATE_MODEL=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST/ml/v4/models?version=2020-08-01&space_id=$SPACE_ID" \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d ''"$MODEL_PAYLOAD"''

  ); then
    echo "Failed to Create Model"
    exit 1
  fi
  sleep 5
  echo "Create Model Completed"
  MODEL_ID=$(echo "$CREATE_MODEL" | jq -r '.metadata.id')
  echo "MODEL_ID*******************$MODEL_ID"
  #Create Deployment
  NAME="Data Fabric AutoAI deployment$UNIQUE_ID"
  if ! CREATE_DEPLOYMENT=$(
    curl -k -X POST \
      "$CPD_CLUSTER_HOST/ml/v4/deployments?version=2020-08-01" \
      -H 'Authorization: Bearer '"$CPD_TOKEN"'' \
      -H 'cache-control: no-cache' \
      -H 'content-type: application/json' \
      -d '{"space_id": "'"$SPACE_ID"'","name": "'"$NAME"'","description": "Data Fabric AutoAI deployment","batch": {}, "hybrid_pipeline_hardware_specs": [{"node_runtime_id": "auto_ai.kb", "hardware_spec": {"name": "M"}}],"asset": {"id": "'"$MODEL_ID"'"}}'

  ); then
    echo "Failed to Create Deployment"
    exit 1
  fi
  sleep 5
  echo "Create Deployment Completed *** $CREATE_DEPLOYMENT"

else
  echo "Please provide CPD_CLUSTER_HOST & CPD_TOKEN "
fi
exit 0
