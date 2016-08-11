variable master_count { }
variable master_flavor { }
variable datacenter { default = "openstack" }
variable image_name { }
variable keypair_name { }
variable net_id { }
variable node_count { }
variable node_flavor { }
variable security_groups { }
variable short_name { default = "k8s" }
variable host_domain { default = "novalocal" }
variable ssh_user { default = "centos" }
variable docker_volume_size { default = "50" }
variable docker_volume_device { default = "/dev/vdb" }

resource "template_file" "cloud-init-master" {
  count         = "${ var.master_count }"
  template      = "terraform/openstack/cloud-config/user-data.yml"
  vars {
    hostname    = "${ var.short_name }-master-${ format("%02d", count.index+1) }"
    host_domain = "${ var.host_domain }"
  }
}

resource "template_file" "cloud-init-node" {
  count         = "${ var.node_count }"
  template      = "terraform/openstack/cloud-config/user-data.yml"
  vars {
    hostname    = "${ var.short_name }-node-${ format("%02d", count.index+1) }"
    host_domain = "${ var.host_domain }"
  }
}

resource "openstack_blockstorage_volume_v1" "master" {
  name = "${ var.short_name }--${format("%02d", count.index+1) }"
  description = "${ var.short_name }-master-docker-${format("%02d", count.index+1) }"
  size = "${ var.docker_volume_size }"
  metadata = {
    usage = "/var/lib/docker"
  }
  count = "${ var.master_count }"
}

resource "openstack_compute_instance_v2" "master" {
  name = "${ var.short_name}-master-${format("%02d", count.index+1) }.${ var.host_domain }"
  key_pair = "${ var.keypair_name }"
  image_name = "${ var.image_name }"
  flavor_name = "${ var.master_flavor }"
  security_groups = [ "${ var.security_groups }", "default" ]
  network = { uuid  = "${ var.net_id }" }
  metadata = {
    dc = "${var.datacenter}"
    role = "master"
    ssh_user = "${ var.ssh_user }"
  }
  volume {
    volume_id = "${ element(openstack_blockstorage_volume_v1.master.*.id, count.index) }"
    device = "${ var.docker_volume_device }"
  }
  count = "${ var.master_count }"
  user_data = "${ element(template_file.cloud-init-master.*.rendered, count.index) }"
}

resource "openstack_blockstorage_volume_v1" "node" {
  name = "${ var.short_name }--${format("%02d", count.index+1) }"
  description = "${ var.short_name }-node-docker-${format("%02d", count.index+1) }"
  size = "${ var.docker_volume_size }"
  metadata = {
    usage = "/var/lib/docker"
  }
  count = "${ var.node_count }"
}

resource "openstack_compute_instance_v2" "node" {
  name = "${ var.short_name}-node-${format("%02d", count.index+1) }.${ var.host_domain }"
  key_pair = "${ var.keypair_name }"
  image_name = "${ var.image_name }"
  flavor_name = "${ var.node_flavor }"
  security_groups = [ "${ var.security_groups }", "default" ]
  network = { uuid = "${ var.net_id }" }
  metadata = {
    dc = "${var.datacenter}"
    role = "node"
    ssh_user = "${ var.ssh_user }"
  }
  volume {
    volume_id = "${ element(openstack_blockstorage_volume_v1.node.*.id, count.index) }"
    device = "${ var.docker_volume_device }"
  }
  count = "${ var.node_count }"
  user_data = "${ element(template_file.cloud-init-node.*.rendered, count.index) }"
}
