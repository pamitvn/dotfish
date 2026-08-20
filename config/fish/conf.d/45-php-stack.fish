# 45-php-stack.fish — php-stack Module: shared helpers for the Docker-aware
# artisan/composer/vendor-bin Wrappers and the php-stack command. (Module
# metadata: modules.toml)
#
# Stack identity (docker|local) is detected per project on the first Wrapper
# call and remembered in a Stack record under ~/.cache/php-stack/. Container
# health is never cached: a docker-stack dispatch requires the recorded
# service to be running, and errors rather than falling back to local.

set -g __php_stack_cache_dir ~/.cache/php-stack

# Service names auto-picked (without prompting) when exactly one is present
# in the project's compose services.
set -g __php_stack_service_candidates app php laravel.test workspace

# Print the canonical compose file in <dir>, if any. Canonical names are the
# ones `docker compose` resolves natively (override files merge on their own).
function __php_stack_compose_file
    for name in docker-compose.yml docker-compose.yaml compose.yml compose.yaml
        if test -f "$argv[1]/$name"
            echo "$argv[1]/$name"
            return 0
        end
    end
    return 1
end

# Print non-canonical compose files in <dir> (e.g. docker-compose.dev.yml),
# as bare filenames. These need an explicit -f to be usable.
function __php_stack_compose_variants
    for f in $argv[1]/*compose*.yml $argv[1]/*compose*.yaml
        set -l name (path basename -- $f)
        if not contains -- $name docker-compose.yml docker-compose.yaml compose.yml compose.yaml
            echo $name
        end
    end
end

# True when <dir> has any compose file at all, canonical or variant.
function __php_stack_has_compose
    __php_stack_compose_file $argv[1] >/dev/null && return 0
    test (count (__php_stack_compose_variants $argv[1])) -gt 0
end

# docker compose scoped to <root>, adding -f for a recorded variant file.
function __php_stack_compose
    set -l opts --project-directory $argv[1]
    test -n "$__php_stack_file"; and set -a opts -f $argv[1]/$__php_stack_file
    docker compose $opts $argv[2..-1]
end

# Walk up from $PWD to the nearest project marker (compose file, composer.json,
# or artisan) and print that directory. Stops at the first marker found.
function __php_stack_root
    set -l dir $PWD
    while true
        if __php_stack_has_compose $dir || test -f "$dir/composer.json" || test -f "$dir/artisan"
            echo $dir
            return 0
        end
        test "$dir" = /; and return 1
        set dir (path dirname $dir)
    end
end

function __php_stack_record_file
    echo $__php_stack_cache_dir/(string escape --style=var -- $argv[1])
end

# Load <root>'s Stack record into __php_stack_stack / __php_stack_service.
function __php_stack_read
    set -g __php_stack_stack ''
    set -g __php_stack_service ''
    set -g __php_stack_file ''
    set -l file (__php_stack_record_file $argv[1])
    test -f $file; or return 1
    while read -l key value
        switch $key
            case stack
                set -g __php_stack_stack $value
            case service
                set -g __php_stack_service $value
            case file
                set -g __php_stack_file $value
        end
    end <$file
    test -n "$__php_stack_stack"
end

function __php_stack_write
    mkdir -p $__php_stack_cache_dir
    set -l file (__php_stack_record_file $argv[1])
    echo "stack $__php_stack_stack" >$file
    test -n "$__php_stack_service"; and echo "service $__php_stack_service" >>$file
    test -n "$__php_stack_file"; and echo "file $__php_stack_file" >>$file
    return 0
end

function __php_stack_services
    __php_stack_compose $argv[1] config --services 2>/dev/null
end

# Determine <root>'s Stack, prompting for the compose service when it cannot
# be auto-picked, and write the Stack record.
function __php_stack_detect
    set -l root $argv[1]
    set -g __php_stack_stack local
    set -g __php_stack_service ''
    set -g __php_stack_file ''

    set -l has_compose 0
    if __php_stack_compose_file $root >/dev/null
        # Canonical file: let docker compose resolve it (and overrides) natively.
        set has_compose 1
    else
        set -l variants (__php_stack_compose_variants $root)
        if test (count $variants) -eq 1
            set -g __php_stack_file $variants[1]
            set has_compose 1
        else if test (count $variants) -gt 1
            # An exported COMPOSE_FILE naming one of the variants settles it.
            if set -q COMPOSE_FILE
                set -l envfirst (path basename -- (string split : -- $COMPOSE_FILE)[1])
                if contains -- $envfirst $variants
                    set -g __php_stack_file $envfirst
                    set has_compose 1
                end
            end
            if test $has_compose -eq 0
                echo "php-stack: no canonical compose file — which one does this project use?" >&2
                for i in (seq (count $variants))
                    echo "  [$i] $variants[$i]" >&2
                end
                read -l -P "compose file number: " choice
                if string match -qr '^\d+$' -- $choice && test $choice -ge 1 && test $choice -le (count $variants)
                    set -g __php_stack_file $variants[$choice]
                    set has_compose 1
                else
                    echo "php-stack: no compose file chosen — aborting" >&2
                    return 1
                end
            end
        end
    end

    if test $has_compose -eq 1
        set -l services (__php_stack_services $root)
        if test -z "$services"
            echo "php-stack: compose file found but its services are unreadable (docker compose config failed)" >&2
            return 1
        end
        set -g __php_stack_stack docker

        set -l hits
        for name in $__php_stack_service_candidates
            contains -- $name $services; and set -a hits $name
        end
        if test (count $hits) -eq 1
            set -g __php_stack_service $hits[1]
        else if test (count $services) -eq 1
            set -g __php_stack_service $services[1]
        else
            echo "php-stack: which service runs PHP in $root?" >&2
            for i in (seq (count $services))
                echo "  [$i] $services[$i]" >&2
            end
            set -l prompt "service number: "
            test (count $hits) -gt 0; and set prompt "service number [default $hits[1]]: "
            read -l -P $prompt choice
            if test -z "$choice" && test (count $hits) -gt 0
                set -g __php_stack_service $hits[1]
            else if string match -qr '^\d+$' -- $choice && test $choice -ge 1 && test $choice -le (count $services)
                set -g __php_stack_service $services[$choice]
            else
                echo "php-stack: no service chosen — aborting" >&2
                return 1
            end
        end
        set -l noted "php-stack: recorded stack=docker service=$__php_stack_service"
        test -n "$__php_stack_file"; and set noted "$noted file=$__php_stack_file"
        echo "$noted for $root" >&2
    end
    __php_stack_write $root
end

# Ensure a valid Stack record exists for <root> (cheap symmetric checks only:
# a local record is stale once any compose file appears, a docker record is
# stale once its compose file — canonical or recorded variant — disappears).
# Service existence is verified lazily at dispatch.
function __php_stack_ensure
    set -l root $argv[1]

    if __php_stack_read $root
        if test "$__php_stack_stack" = local
            __php_stack_has_compose $root; or return 0
        else if test "$__php_stack_stack" = docker && test -n "$__php_stack_service"
            if test -n "$__php_stack_file"
                test -f "$root/$__php_stack_file"; and return 0
            else
                __php_stack_compose_file $root >/dev/null; and return 0
            end
        end
    end
    __php_stack_detect $root
end

# Run <tool> inside the recorded compose service. Containers must be running:
# a stopped service is a hard error, never a silent local fallback.
function __php_stack_exec_docker
    set -l root $argv[1]
    set -l tool $argv[2]
    set -l args $argv[3..-1]

    set -l running (__php_stack_compose $root ps --status running --services 2>/dev/null)
    if not contains -- $__php_stack_service $running
        if contains -- $__php_stack_service (__php_stack_services $root)
            echo "php-stack: service '$__php_stack_service' is not running — start it (docker compose up -d) and retry" >&2
            return 1
        end
        echo "php-stack: recorded service '$__php_stack_service' is gone from the compose file — re-detecting" >&2
        __php_stack_detect $root; or return 1
        __php_stack_dispatch $tool $args
        return
    end

    switch $tool
        case artisan
            __php_stack_compose $root exec $__php_stack_service php artisan $args
        case composer
            __php_stack_compose $root exec $__php_stack_service composer $args
        case '*'
            # Any other tool is a vendor binary; the compose service's
            # working_dir is the app root, so the relative path resolves.
            __php_stack_compose $root exec $__php_stack_service vendor/bin/$tool $args
    end
end

# Entry point shared by the artisan/composer Wrappers.
function __php_stack_dispatch
    set -l tool $argv[1]
    set -l args $argv[2..-1]

    set -l root (__php_stack_root)
    if test -z "$root"
        switch $tool
            case composer
                if not command -q composer
                    echo "php-stack: composer is not installed on this machine" >&2
                    return 127
                end
                command composer $args
                return
            case artisan
                echo "php-stack: not inside a PHP project (no compose file, composer.json, or artisan found upward of $PWD)" >&2
                return 1
            case '*'
                # Vendor tools fall back to a global install outside a project,
                # mirroring the composer behaviour.
                if not command -q $tool
                    echo "php-stack: not inside a PHP project and $tool is not installed globally" >&2
                    return 127
                end
                command $tool $args
                return
        end
    end

    __php_stack_ensure $root; or return 1

    switch $__php_stack_stack
        case docker
            __php_stack_exec_docker $root $tool $args
        case local
            switch $tool
                case artisan
                    if not test -f "$root/artisan"
                        echo "php-stack: $root has no artisan script" >&2
                        return 1
                    end
                    php $root/artisan $args
                case composer
                    if not command -q composer
                        echo "php-stack: composer is not installed on this machine" >&2
                        return 127
                    end
                    command composer $args
                case '*'
                    if not test -x "$root/vendor/bin/$tool"
                        echo "php-stack: $root/vendor/bin/$tool not found — run composer install (or 'command $tool' for a global install)" >&2
                        return 127
                    end
                    $root/vendor/bin/$tool $args
            end
    end
end

# Vendor-bin Wrappers: each tool in $php_stack_vendor_tools gets a Wrapper that
# dispatches vendor/bin/<tool> on the project Stack (see also: vbin). Override
# the list before this file loads (e.g. in a conf.d file sorting earlier) to
# change which Wrappers are defined.
set -q php_stack_vendor_tools; or set -g php_stack_vendor_tools pest phpunit pint phpstan
for __php_stack_tool in $php_stack_vendor_tools
    function $__php_stack_tool --inherit-variable __php_stack_tool --description "php-stack: $__php_stack_tool on the project Stack"
        __php_stack_dispatch $__php_stack_tool $argv
    end
end
set -e __php_stack_tool
