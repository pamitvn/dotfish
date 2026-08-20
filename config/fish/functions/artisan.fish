# artisan — php-stack Wrapper: runs artisan on the project's Stack.
# docker → `docker compose exec <service> php artisan`, local → `php artisan`.
function artisan --description 'php-stack: artisan on the project Stack'
    __php_stack_dispatch artisan $argv
end
