require "./gh-shard/*"
require "file_utils"
# require "option_parser"
include FileUtils

module Gh::Shard
  # TODO Put your code here
end

def crystal
  ENV.fetch("CRYSTAL", "crystal")
end

def remote_name
  ENV.fetch("REMOTE_NAME", "origin")
end

def branch_name
  ENV.fetch("BRANCH_NAME", "gh-pages")
end

def uncommitted_changes?
  `git status --porcelain`.chomp.size > 0
end

options = ARGV
command = options.first?
options.shift

case command
when "publish-docs"
  puts "publishing docs..."

  tag = `git describe --tags --exact-match 2> /dev/null`.chomp
  tag = tag[1..-1] if tag.starts_with?("v")
  tag = options.first? if tag.empty?
  if tag.nil? || tag.empty?
    puts "No tag found run as `gh-shard publish-docs [tag]"
    exit 1
  end

  `#{crystal} docs`

  project_root = ENV.fetch("PROJECT_ROOT", `git rev-parse --show-toplevel`.chomp)
  build_dir = ENV.fetch("BUILD_DIR", File.join(project_root, ".gh-pages"))
  api_dir = "#{build_dir}/api"
  gh_pages_ref = File.join(build_dir, ".git/refs/remotes/#{remote_name}/#{branch_name}")
  repo_url = `git config --get remote.#{remote_name}.url`.chomp

  rm_rf build_dir
  mkdir_p build_dir
  cd build_dir do
    `git init`
    `git remote add #{remote_name} #{repo_url}`
    `git fetch --depth 1 #{remote_name}`

    if `git branch -r` =~ /#{branch_name}/
      `git checkout #{branch_name}`
    else
      `git checkout --orphan #{branch_name}`
      File.write("_config.yml",
        <<-EOF
        gems:
          - jekyll-redirect-from
        EOF
      )
      `touch index.html`
      `git add .`
      `git commit -m \"initial gh-pages commit\"`
      `git push #{remote_name} #{branch_name}`
    end

    mkdir_p api_dir

    # DRY
    target_dir = "#{api_dir}/#{tag}"
    rm_rf target_dir
    cp_r "../doc", target_dir

    `git add --all`
    if uncommitted_changes?
      message = "publishing docs for #{tag}"
      `git commit -m \"#{message}\"`
    else
      puts "No changes to commit."
    end
    `git push #{remote_name} #{branch_name}`
  end
when "redirect"
  puts "redirecting docs..."

  from = options.first
  options.shift

  to = options.first
  # TODO make [to] arg optional and grab current tag

  project_root = ENV.fetch("PROJECT_ROOT", `git rev-parse --show-toplevel`.chomp)
  build_dir = ENV.fetch("BUILD_DIR", File.join(project_root, ".gh-pages"))
  api_dir = "#{build_dir}/api"
  gh_pages_ref = File.join(build_dir, ".git/refs/remotes/#{remote_name}/#{branch_name}")
  repo_url = `git config --get remote.#{remote_name}.url`.chomp

  rm_rf build_dir
  mkdir_p build_dir
  cd build_dir do
    `git init`
    `git remote add #{remote_name} #{repo_url}`
    `git fetch --depth 1 #{remote_name}`

    if `git branch -r` =~ /#{branch_name}/
      `git checkout #{branch_name}`
    else
      `git checkout --orphan #{branch_name}`
      File.write("_config.yml",
        <<-EOF
        gems:
          - jekyll-redirect-from
        EOF
      )
      `touch index.html`
      `git add .`
      `git commit -m \"initial gh-pages commit\"`
      `git push #{remote_name} #{branch_name}`
    end

    mkdir_p api_dir

    # DRY
    from_dir = "#{api_dir}/#{from}"
    to_dir = "#{api_dir}/#{to}"
    rm_rf from_dir
    mkdir_p from_dir

    # TODO handle nested directory
    # TODO handle top level index /latest -> /0.1.0 (maybe redirect_from)
    Dir["#{to_dir}/*.html"].each do |dest|
      dest_name = File.basename(dest)
      File.write("#{from_dir}/#{dest_name}.md",
        <<-MD
        ---
        redirect_to:
          - ../#{to}/#{dest_name}
        ---
        MD
      )
    end

    `git add --all`
    if uncommitted_changes?
      message = "publishing redirect #{from} -> #{to}"
      `git commit -m \"#{message}\"`
    else
      puts "No changes to commit."
    end
    `git push #{remote_name} #{branch_name}`
  end
else
  puts "TODO USAGE"
end
