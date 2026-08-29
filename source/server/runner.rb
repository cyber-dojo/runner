require_relative 'cyber_dojo_sh_runner'
require_relative 'files_delta'
require_relative 'home_files'
require_relative 'sandbox'
require_relative 'docker_image_name'
require_relative 'lib/tarfile_reader'
require_relative 'lib/tgz'
require_relative 'traffic_light'
require_relative 'lib/utf8_clean'

class Runner
  def initialize(context)
    @context = context
    @traffic_light = TrafficLight.new(context)
  end

  def run_cyber_dojo_sh(id:, files:, manifest:)
    image_name = manifest['image_name']
    # Checked here rather than left to pull_image's own tagging, so that what
    # the manifest says is this method's business and a run never depends on
    # how far a bad name happens to travel before something objects.
    ::DockerImageName.assert_versioned(image_name)

    return empty_result(:pulling, 'pulling', {}) unless images.pull(id: id, image_name: image_name) == :pulled

    run, files_in = run_cyber_dojo_sh_inner(id, files, manifest)

    if run[:timed_out]
      log(id: id, image_name: image_name, message: 'timed_out', result: utf8_clean(run))
      return timed_out_result(run)
    end

    tgz_out = run[:stdout]
    files_out, stdout, stderr, status = files_sss_from(tgz_out)

    sss = [stdout['content'], stderr['content'], status['content']]
    if manifest.key?('rag_lambda')
      colour, log_info = *@traffic_light.colour_from_lambda(manifest['rag_lambda'], *sss)
    else
      colour, log_info = *@traffic_light.colour_from_image(image_name, *sss)
    end

    created, changed = files_delta(files_in, files_out)
    result(
      stdout, stderr, status['content'],
      colour, log_info,
      Sandbox.out(at_most(16, created)),
      Sandbox.out(changed)
    )
  rescue CyberDojoShRunner::ImageMissing => e
    # Forgetting the image is what lets a later test-run pull it again. This
    # refusal is the only sign the runner gets that what @pulled believes
    # about the node is wrong, and believing it anyway makes every later
    # test-run for this image faulty too.
    images.forget(image_name)
    log(id: id, image_name: image_name, error: e.message)
    faulty_result({})
  rescue CyberDojoShRunner::DaemonRefused => e
    # The daemon would not run the kata, so there is no result to report and
    # nothing the kata did wrong. The learner is owed a traffic light rather
    # than a 500, and what the daemon said belongs in the log rather than in
    # the browser. The image is left alone: this refusal says nothing about
    # what the node holds.
    log(id: id, image_name: image_name, error: e.message)
    faulty_result({})
  rescue Zlib::GzipFile::Error, Gem::Package::TarInvalidError => e
    # Zlib rejects a payload whose gzip CRC32 or length trailer does not
    # match; TarFile::Reader rejects one that inflates to something which is
    # not a tar. Either way the container did not send a run result, and
    # nothing in it may reach the browser.
    log(id: id, image_name: image_name, error: e.class.name)
    # The container's stderr is the only account of why there is no payload,
    # eg tini reporting that it could not exec bash. Losing it leaves nothing
    # to diagnose a run that produced nothing.
    utf8_clean(run)
    empty_result(:corrupt_payload, 'faulty', run)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Runner's requirements on image_name.
  #   o) sandbox user, uid=41966, gid=51966, home=/home/sandbox
  #   o) commands: bash, file, grep, tar, truncate
  # These are satisfied by image_name being built with
  # https://github.com/cyber-dojo-tools/image_dockerfile_augmenter

  KB = 1024

  MAX_FILE_SIZE = 50 * KB # of stdout, stderr, created, changed

  STATUS = {
    pulling: 141,
    timed_out: 142,
    faulty: 143,
    corrupt_payload: 144
  }.freeze

  private

  include FilesDelta
  include HomeFiles

  def run_cyber_dojo_sh_inner(id, files, manifest)
    image_name = manifest['image_name']
    random_id = @context.random.hex8
    container_name = ['cyber_dojo_runner', id, random_id].join('_')
    max_seconds = [CyberDojoShRunner::RUN_SECONDS, Integer(manifest['max_seconds'])].min
    files_in = Sandbox.in(files)
    tgz_in = TGZ.of(files_in.merge(home_files(Sandbox::DIR, MAX_FILE_SIZE)))

    run = CyberDojoShRunner.new(@context).run(id, image_name, container_name, max_seconds, tgz_in)

    [run, files_in]
  end

  def files_sss_from(tgz_out)
    files_out = TGZ.files(tgz_out).each.with_object({}) do |(filename, content), memo|
      memo[filename] = truncated(content)
    end
    stdout = files_out.delete('tmp/stdout') || truncated('')
    stderr = files_out.delete('tmp/stderr') || truncated('')
    status = files_out.delete('tmp/status') || truncated('145')
    [files_out, stdout, stderr, status]
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def timed_out_result(run)
    empty_result(:timed_out, 'timed_out', run)
  end

  def faulty_result(run)
    empty_result(:faulty, 'faulty', run)
  end

  def empty_result(code, outcome, log_info)
    result(
      truncated(''), truncated(''), STATUS[code].to_s,
      outcome, log_info,
      {}, {}
    )
  end

  def result(stdout, stderr, status, outcome, log, created, changed)
    {
      'stdout' => stdout, 'stderr' => stderr, 'status' => status,
      'outcome' => outcome, 'log' => log,
      'created' => created, 'changed' => changed
    }
  end

  def truncated(raw_content)
    content = Utf8.clean(raw_content)
    {
      'content' => content[0...MAX_FILE_SIZE],
      'truncated' => content.size > MAX_FILE_SIZE
    }
  end

  def at_most(size, new_files)
    # Limit number of created text files returned to browser.
    # NB: I tried to do this inside the run container, using
    # home_files.rb like this...
    #   function print0_filenames()
    #   {
    #     find #{sandbox_dir} -type f -print0 | head -z -n LIMIT
    #   }
    # ...but this this can exclude files such as
    # cyber-dojo.sh, makefile, hiker.h, hiker.c etc
    # which then become deleted files!
    new_files.keys.sort[0...size].to_h { |filename| [filename, new_files[filename]] }
  end

  def utf8_clean(result)
    result[:stdout] = Utf8.clean(result[:stdout])
    result[:stderr] = Utf8.clean(result[:stderr])
  end

  def log(info)
    @context.logger.log(JSON.generate(info))
  end

  def images
    @context.images
  end
end
