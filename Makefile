COMMON_CONF += postfix-local apache-credit apache-vhost

CREDIT_LOCATION = ~ "^/(?!(docs))"

include $(FAB_PATH)/common/mk/turnkey/mysql.mk
include $(FAB_PATH)/common/mk/turnkey.mk
