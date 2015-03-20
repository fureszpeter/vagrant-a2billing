# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
    config.vm.box = "ubuntu/trusty64"

    config.vm.synced_folder "./", "/vagrant/", id: "vagrant-root",
        owner: "vagrant",
        group: "www-data",
        mount_options: ["dmode=775"]

    config.vm.hostname = 'admin.a2b.dev'
    config.hostmanager.aliases = %w(agent.a2b.dev user.a2b.dev)
    config.hostmanager.enabled = true
    config.hostmanager.manage_host = true

    config.vm.provision :shell, :path => "vagrant/bootstrap.sh"
    config.vm.network "forwarded_port", guest: 80, host: 8080
    config.vm.network "forwarded_port", guest: 3306, host: 3306
    #sip
    config.vm.network "forwarded_port", guest: 5060, host: 5060, protocol: 'udp'
    config.vm.network "forwarded_port", guest: 4569, host: 4569, protocol: 'udp'
    config.vm.network "forwarded_port", guest: 5036, host: 5036, protocol: 'udp'
end
