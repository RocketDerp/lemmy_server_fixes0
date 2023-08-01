#!/usr/bin/env bash
set -e

bypass_pg_purge=true;
bypass_drone_prep=false;

export LEMMY_DATABASE_URL=postgres://lemmy:password@localhost:5432
export LEMMY_SYNCHRONOUS_FEDERATION=1 # currently this is true in debug by default, but still.
pushd ..
cargo build
rm target/lemmy_server || true
cp target/debug/lemmy_server target/lemmy_server

if [ "$bypass_drone_prep" = false ]
then
echo "prepare drone federation instances"
./api_tests/prepare-drone-federation-test.sh
fi
popd


bypass_yarn=true

yarn

for INSTANCE in lemmy_alpha lemmy_beta lemmy_gamma lemmy_delta lemmy_epsilon; do
  # reminder: PostgreSQL can convert to JSON
  # in postgress config file, set:
  #   shared_preload_libraries = 'pg_stat_statements'	# (change requires restart)
  #   pg_stat_statements.track = all
  psql "$LEMMY_DATABASE_URL" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
  psql "$LEMMY_DATABASE_URL" -c "SELECT pg_stat_statements_reset();"
done



if [ "$bypass_yarn" = false ]
then
  echo ":::: running yarn api-test"
  yarn api-test || true
#    "api-test": "jest -i follow.spec.ts && jest -i src/post.spec.ts && jest -i comment.spec.ts && jest -i private_message.spec.ts && jest -i user.spec.ts && jest -i community.spec.ts"
# yarn api-test
# node jest -i follow.spec.ts
else

  runjest() {
      echo ":::: run jest script $1"
      ./node_modules/.bin/jest $1
      echo ":::: jest exited with code $?"
      if [ $? -eq 0 ]
      then
        echo "good test run"
      else
        echo "bad test results"
        read -p "Press any key to resume ..."
      fi
  }

# why do some have src? others do not?
# package.json has this too
  #runjest src/follow.spec.ts
  # runjest post.spec.ts
  #runjest comment.spec.ts
  #runjest private_message.spec.ts
  # runjest user.spec.ts
  #runjest community.spec.ts
  #runjest remote_to_remote.spec.ts
  #runjest aggregates.spec.ts
  # runjest remote_home_remote.spec.ts
  runjest benchmark_baseline.spec.ts
  # runjest benchmark_concurrent.spec.ts
  # runjest live_servers.spec.ts

fi

for INSTANCE in lemmy_alpha lemmy_beta lemmy_gamma lemmy_delta lemmy_epsilon; do
  # reminder: PostgreSQL can convert to JSON
  psql "$LEMMY_DATABASE_URL" -c "SELECT queryid, calls, rows, mean_exec_time, query FROM pg_stat_statements ORDER BY calls DESC;" > /tmp/${INSTANCE}_stat_statements.txt
done


if [ "$bypass_pg_purge" = false ]; then

killall -s1 lemmy_server

for INSTANCE in lemmy_alpha lemmy_beta lemmy_gamma lemmy_delta lemmy_epsilon; do
  psql "$LEMMY_DATABASE_URL" -c "DROP DATABASE $INSTANCE"
done

fi
