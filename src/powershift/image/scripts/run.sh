#!/bin/bash

echo " -----> Running application run script."

# Ensure we fail fast if there is a problem.

set -eo pipefail

# It is presumed that the directory '/usr/libexec/s2i' contains the
# original S2I 'assemble' and 'build' scripts.

S2I_SCRIPTS_PATH=${S2I_SCRIPTS_PATH:-/usr/libexec/s2i}
export S2I_SCRIPTS_PATH

# The implementation of the action hooks mechanism implemented by the
# 'assemble' and 'run' scripts included here are designed around the
# idea that the directory '/opt/app-root' is the top level directory
# which is used by an application. Also, that the '/opt/app-root/src'
# directory will be the current working directory when the 'assemble'
# and 'run' scripts are run. Abort the script if the latter isn't the
# case.

S2I_APPLICATION_PATH=${S2I_APPLICATION_PATH:-/opt/app-root}
export S2I_APPLICATION_PATH

S2I_SOURCE_PATH=${S2I_SOURCE_PATH:-${S2I_APPLICATION_PATH}/src}
export S2I_SOURCE_PATH

if [ x"$S2I_SOURCE_PATH" != x`pwd` ]; then
    echo "ERROR: Working directory of 'run' script is not $S2I_SOURCE_PATH."
    exit 1
fi

# Now source the 'deploy_env' script from the '.s2i/action_hooks'
# directory if it exists. This script allows a user to dynamically set
# additional environment variables required by the deploy process. These
# might for example be environment variables which tell an application
# where files it requires are located. When we source the 'deploy_env'
# script, any environment variables set by it will be automatically
# exported. Note that we only source the 'deploy_env' script if it hasn't
# already been run. It could have already been run from the shell login
# environment.

if [ x"S2I_MARKERS_ENVIRON" != x"" ]; then
    S2I_MARKERS_ENVIRON=`/usr/bin/date`
    export S2I_MARKERS_ENVIRON

    if [ -f $S2I_SOURCE_PATH/.s2i/action_hooks/deploy_env ]; then
        echo " -----> Running $S2I_SOURCE_PATH/.s2i/action_hooks/deploy_env"
        S2I_SHELL_PWD=$PWD
        set -a; . $S2I_SOURCE_PATH/.s2i/action_hooks/deploy_env; set +a
        cd $S2I_SHELL_PWD
    fi
fi

# Now run the 'deploy' hook from the '.s2i/action_hooks' directory if it
# exists. This hook is to allow a user to run any final steps just before
# the application is to be started. This can include running background
# tasks.

if [ -f $S2I_SOURCE_PATH/.s2i/action_hooks/deploy ]; then
    if [ ! -x $S2I_SOURCE_PATH/.s2i/action_hooks/deploy ]; then
        echo "ERROR: Script $S2I_SOURCE_PATH/.s2i/action_hooks/deploy not executable."
        exit 1
    else
        echo " -----> Running $S2I_SOURCE_PATH/.s2i/action_hooks/deploy"
        $S2I_SOURCE_PATH/.s2i/action_hooks/deploy
    fi
fi

# Now run a user provided 'run' script if it exists, as a complete
# replacement for the original 'run' script. This will replace this
# process and so nothing below this point will be run.

if [ -f $S2I_SOURCE_PATH/.s2i/action_hooks/run ]; then
    if [ ! -x $S2I_SOURCE_PATH/.s2i/action_hooks/run ]; then
        echo "ERROR: Script $S2I_SOURCE_PATH/.s2i/action_hooks/run not executable."
        exit 1
    else
        echo " -----> Running $S2I_SOURCE_PATH/.s2i/action_hooks/run"
        exec $S2I_SOURCE_PATH/.s2i/action_hooks/run
    fi
fi

# If we get this far run the original 'run' script to start up the
# application. This must be run using 'exec' so that the original 'run'
# script will take over process ID 1. This is necessary so that the
# application will receive signals properly.

echo " -----> Running builder run script ($S2I_SCRIPTS_PATH/run)"

exec $S2I_SCRIPTS_PATH/run
