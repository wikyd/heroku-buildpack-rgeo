class LanguagePack::Ruby < LanguagePack::Base
  def rgeo_url(filename = nil)
    "https://s3.amazonaws.com/camenischcreative/heroku-binaries/rgeo/#{filename}"
  end

  def binaries
    {geos: '3.3', proj: '4.8'}
  end

  def binary_names
    binaries.keys
  end

  alias_method :orig_default_config_vars, :default_config_vars
  def default_config_vars
    orig_default_config_vars.tap do |vars|
      vars['PATH'] = (vars['PATH'] || '') << ':' << binary_names.map{|name| "/app/bin/#{name}/lib" }.join(':')
    end
  end

  def install_rgeo_binary(name, version)
    bin_dir = "bin/#{name}"
    FileUtils.mkdir_p bin_dir
    filename = "#{name}-#{version}.tgz"
    topic("Downloading #{name} from #{rgeo_url(filename)}")
    Dir.chdir(bin_dir) do |dir|
      run("curl #{rgeo_url(filename)} -s -o - | tar xzf -")
    end
  end

  def pwd
    run('pwd').chomp
  end

  def puts_and_pipe(cmd)
    puts '> ' << cmd
    pipe cmd
  end

  alias_method :orig_compile, :compile
  def compile
    # Recompile all gems if 'requested' via environment variable
    # The user-env-compile labs feature must be enabled for this to work
    # See https://devcenter.heroku.com/articles/labs-user-env-compile
    cache_clear("vendor/bundle") if ENV['RECOMPILE_ALL_GEMS'] =~ /^(true|on|yes|1)$/


    binaries.each do |(name, version)|
      install_rgeo_binary(name, version)
    end
    binary_names.each {|name| puts_and_pipe "ls #{pwd}/bin" }
    ENV['BUNDLE_BUILD__RGEO'] = binary_names.map{|name| "--with-#{name}-dir=#{pwd}/bin"}.join(' ')
    puts ENV.to_hash.inspect
    orig_compile
  end
end
