# composer — php-stack Wrapper: runs composer on the project's Stack.
# docker → `docker compose exec <service> composer`, local/outside a project →
# the real composer (`command composer`).
function composer --description 'php-stack: composer on the project Stack'
    __php_stack_dispatch composer $argv
end
