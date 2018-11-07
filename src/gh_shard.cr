require "./gh_shard/*"
require "file_utils"
# require "option_parser"
include FileUtils

module GhShard
  record Config, crystal : String, remote_name : String,
    branch_name : String, api_prefix : String

  def self.config
    Config.new(
      crystal: ENV.fetch("CRYSTAL", "crystal"),
      remote_name: ENV.fetch("REMOTE_NAME", "origin"),
      branch_name: ENV.fetch("BRANCH_NAME", "gh-pages"),
      api_prefix: ENV.fetch("API_PREFIX", "/api")
    )
  end

  def self.on_build_dir(git, config)
    project_root = ENV.fetch("PROJECT_ROOT", `git rev-parse --show-toplevel`.chomp)
    build_dir = ENV.fetch("BUILD_DIR", File.join(project_root, ".gh-pages"))

    api_dir = "#{build_dir}#{config.api_prefix}"
    gh_pages_ref = File.join(build_dir, ".git/refs/remotes/#{config.remote_name}/#{config.branch_name}")
    repo_url = `git config --get remote.#{config.remote_name}.url`.chomp

    baseurl = "CHANGE_ME"
    if md = repo_url.match /github\.com(?:\:|\/)(?<user>(?:\w|-|_)+)\/(?<repo>(?:\w|-|_|\.)+?)(?:\.git)?$/
      baseurl = md["repo"]
    end

    rm_rf build_dir
    mkdir_p build_dir
    cd build_dir do
      `git init`
      `git remote add #{config.remote_name} #{repo_url}`
      `git fetch --depth 1 #{config.remote_name}`

      if `git branch -r` =~ /#{config.branch_name}/
        `git checkout #{config.branch_name}`
      else
        `git checkout --orphan #{config.branch_name}`
        File.write("_config.yml",
          <<-EOF
          gems:
            - jekyll-redirect-from
          baseurl: /#{baseurl}
          EOF
        )
        `touch index.html`

        git.perfom_commit_push "initial gh-pages commit"
      end

      mkdir_p api_dir

      yield api_dir
    end
  end

  class GitHelper
    # TODO @commit : Bool, @push : Bool
    def initialize(@config : Config)
    end

    def uncommitted_changes?
      `git status --porcelain`.chomp.size > 0
    end

    def perfom_commit_push(message)
      `git add --all`

      if uncommitted_changes?
        `git commit -m \"#{message}\"`
      else
        puts "No changes to commit."
      end
      `git push #{@config.remote_name} #{@config.branch_name}`
    end

    def tag
      `git describe --tags --exact-match 2> /dev/null`.chomp
    end
  end

  class DocsPublisher
    def initialize(@config : Config, @options : Array(String))
      @git = GitHelper.new(@config)
    end

    def run
      puts "publishing docs..."

      tag = @git.tag
      tag = tag[1..-1] if tag.starts_with?("v")
      tag = @options.first? if tag.empty?
      if tag.nil? || tag.empty?
        puts "No tag found run as `ghshard publish-docs [tag]"
        exit 1
      end

      `#{@config.crystal} docs`

      GhShard.on_build_dir @git, @config do |api_dir|
        target_dir = "#{api_dir}/#{tag}"
        rm_rf target_dir
        cp_r "../docs", target_dir
        @git.perfom_commit_push "publishing docs for #{tag}"
      end
    end
  end

  class DocsRedirector
    def initialize(@config : Config, @options : Array(String))
      @git = GitHelper.new(@config)
    end

    def run
      puts "redirecting docs..."

      from = @options.first
      @options.shift
      to = @options.first
      # TODO make [to] arg optional and grab current tag

      GhShard.on_build_dir @git, @config do |api_dir|
        # TODO add checks that jekyll-redirect-from is enabled
        from_dir = "#{api_dir}/#{from}"
        to_dir = "#{api_dir}/#{to}"
        rm_rf from_dir
        mkdir_p from_dir

        Dir["#{to_dir}/**/{*.html,*.md}"].each do |dest|
          relative_file = dest[to_dir.size + 1..-1]
          relative_file_no_ext = relative_file[0..-File.extname(relative_file).size - 1]

          target_url = "#{@config.api_prefix}/#{to}#{relative_file_no_ext != "index" ? "/#{relative_file_no_ext}.html" : ""}"
          redirector_file = "#{from_dir}/#{relative_file_no_ext}.md"
          mkdir_p File.dirname(redirector_file)

          File.write(redirector_file,
            <<-MD
            ---
            redirect_to:
              - #{target_url}
            ---
            MD
          )
        end

        @git.perfom_commit_push "publishing redirect #{from} -> #{to}"
      end
    end
  end

  def self.run(options)
    command = options.first?
    options.shift if command

    case command
    when "docs:publish"
      DocsPublisher.new(GhShard.config, options).run
    when "docs:redirect"
      DocsRedirector.new(GhShard.config, options).run
    else
      puts <<-USAGE
      $ ghshard docs:publish [TAG]
        - ./ghshard docs:publish
          use the current tag as TAG
        - ./ghshard docs:publish 0.3.4
          publish the content of `crystal docs` under /api/0.3.4

      $ ghshard docs:redirect FROM TO
        - ./ghshard docs:redirect 0.3 0.3.4
          publish a redirect for /api/0.3/* to /api/0.3.4/*
        - ./ghshard docs:redirect latest 0.3
          publish a redirect for /api/latest/* to /api/0.3/*

      USAGE
    end
  end
end
