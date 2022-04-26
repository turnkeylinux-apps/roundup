COMMON_CONF += apache-credit

CREDIT_LOCATION = ~ "^/(?!(docs))"

include $(FAB_PATH)/common/mk/turnkey/apache.mk
include $(FAB_PATH)/common/mk/turnkey/mysql.mk
include $(FAB_PATH)/common/mk/turnkey.mk
