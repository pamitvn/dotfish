# vbin — php-stack Wrapper: runs any vendor/bin tool on the project's Stack.
# docker → `docker compose exec <service> vendor/bin/<tool>`, local →
# `<root>/vendor/bin/<tool>`. For tools used often, add them to
# $php_stack_vendor_tools instead to get a direct Wrapper (see 45-php-stack.fish).
function vbin --description 'php-stack: run a vendor/bin tool on the project Stack'
    if test (count $argv) -eq 0
        echo "usage: vbin <tool> [args...]" >&2
        return 2
    end
    __php_stack_dispatch $argv
end
