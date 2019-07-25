require "net/http"
require "oga"

class Auditor
  Dependency = Struct.new(:name, :current_version, :new_version, :update_info_list) do
    # Returns first update note that includes security keyword
    def vulnerability_info(pattern = /(vulnerability|vulnerabilities|security|attack|advisory|unsecure|critical|alert|emergency)/)
      update_info_list.detect { |i| i.downcase.match?(pattern) }
    end
  end

  def get_repo(name) # TODO: fix this
    # TODO: call and parse pod search output here
    "#{name}/#{name}" # repo assumed to `github.com/repo_name/repo_name`
  end

  def make_request(url)
    uri = URI(url)

    _ = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      req = Net::HTTP::Get.new(uri.request_uri)
      http.request(req)
    end
  end

  def get_list_items_from_html(html)
    update_info = []

    d = Oga.parse_html(html)
    _ = d.css(".markdown-body").each do |n|
      n.css("ul li").each do |l|
        update_info << l.text
      end
    end

    update_info
  end

  def run
    IO.popen("cat cocoapods_output.txt", "r") do |output| # make into call to bundle exec pod outdated
      output.readlines.each do |line|
        next unless matches = line.match(/^- (\w+) ([\d\.]+) ->.*latest version ([\d\.]+)/)

        name = matches[1]
        current_version = matches[2]
        new_version = matches[3]

        dep = Dependency.new(name, current_version, new_version, nil)

        puts "name #{dep.name} v #{dep.current_version} n #{dep.new_version}"

        next if current_version == new_version

        repo = get_repo(name)
        url = "https://github.com/#{repo}/releases/tag/#{new_version}"
        puts url
        resp = make_request(url)

        next unless resp.code == "200"

        update_info_list = get_list_items_from_html(resp.body)
        dep.update_info_list = update_info_list

        # yield dep # TODO:
      end
    end
  end
end
