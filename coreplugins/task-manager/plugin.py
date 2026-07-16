from app.plugins import PluginBase, Menu, MountPoint
from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from django.utils.translation import gettext as _


class Plugin(PluginBase):
    def main_menu(self):
        return [Menu(_("Task Manager"), self.public_url(""), "fa fa-hdd fa-fw")]

    def app_mount_points(self):
        @login_required
        def index_view(request):
            return render(request, self.template_path("index.html"), {
                'title': _("Task Manager")
            })

        return [
            MountPoint('$', index_view),
            # more mount points here ...
        ]

    def include_js_files(self):
        return ['main.js']

    def include_css_files(self):
        return ['style.css']

