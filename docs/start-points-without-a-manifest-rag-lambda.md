# Start-points without a manifest rag_lambda

Which languages still make the runner read the red-amber-green lambda out of
their image, rather than being handed it in the manifest.

runner.rb branches on this per test-run:

    if manifest.key?('rag_lambda')
      colour, log_info = *@traffic_light.colour_from_lambda(manifest['rag_lambda'], *sss)
    else
      colour, log_info = *@traffic_light.colour_from_image(image_name, *sss)
    end

The else arm is the expensive one. It runs a whole container
(`docker run --rm --entrypoint=cat <image> /usr/local/bin/red_amber_green.rb`)
to read one file, and it is the last docker CLI caller on any request path.
TrafficLight caches the result per image, so the cost falls on the first
test-run for an image after a runner restart, not on every test-run.

## The count

Audited 2026-08-27, statically, over the working copies in
~/repos/cyber-dojo-start-points. Each start-point is its own git repo, so
there is no single sha to pin here.

83 language start-points, each with a start_point/manifest.json. The three
directories that have none (memory, pinned-checkout, shared-scripts) are not
languages.

  71  manifest has "rag_lambda": "red_amber_green.rb", and the file is present
  12  manifest has no rag_lambda key, and no red_amber_green.rb beside it

71 + 12 = 83. The 71 positives are what proves the search pattern, so the 12
zeroes are a real absence rather than a miscalibrated grep.

## The 12 on the image path

  clang / clang++    clang-cgreen
                     clangplusplus-catch
                     clangplusplus-cgreen
                     clangplusplus-googletest
                     clangplusplus-igloo

  java               java-cucumberpico
                     java-cucumberspring
                     java-jmock
                     java-mockito
                     java-powermockito
                     java-sqlite

  other              visual-basic-nunit

Two clusters rather than a scatter. Eleven of the twelve are clang or java,
which points at a shared cause in how those image families were built rather
than at twelve independent omissions. Finding that cause is likely to fix them
as a batch.

## What is not established here

The manifest value is a filename, "red_amber_green.rb", not the lambda source.
runner.rb passes manifest['rag_lambda'] straight into colour_from_lambda as
lambda_source, so something between the start-point and the runner substitutes
the file's content for its name. That step has not been read, and until it has,
this audit says which start-points carry the file, not that all 71 reach the
runner as source.

docs/api.md documents only the image route, at /usr/local/bin/red_amber_green.rb.
The rag_lambda manifest field is undocumented there.

docs/rag-functions-into-manifest.txt is the plan this audit measures progress
against. It goes further than a manifest field: rag functions in JavaScript,
run in the browser, with a ragger service as the fallback for images that
cannot be upgraded. Those 12 are exactly the population that fallback exists
for.

## Zero here does not delete the image route

Reaching 0 of 83 would empty the else arm of everything a start-point can
reach, and no further. The route stays reachable for anything the start-points
do not cover: a fork of an old kata whose manifest predates the field, and an
image someone built themselves. Neither can be counted by an audit like this
one, and neither can be upgraded by whoever maintains the runner.

So converting the 12 buys the common case, not the branch. Deleting
colour_from_image means moving that fallback somewhere else, which is what the
ragger service in docs/rag-functions-into-manifest.txt is for. Until it exists,
the image route is load-bearing however many start-points carry the field.

This is what decides step 3 of docs/dropping-the-dind-base-image.md, which
wants the route empty so the last docker CLI caller converts by deletion.
Empty of start-points is not empty of callers.
