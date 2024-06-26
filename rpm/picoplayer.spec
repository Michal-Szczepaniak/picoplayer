Name:       picoplayer

%{!?qtc_qmake:%define qtc_qmake %qmake}
%{!?qtc_qmake5:%define qtc_qmake5 %qmake5}
%{!?qtc_make:%define qtc_make make}
%{?qtc_builddir:%define _builddir %qtc_builddir}
Summary:    Pico Player is minimal video player
Version:    1.5
Release:    1
Group:      Qt/Qt
License:    LICENSE
URL:        http://example.org/
Source0:    %{name}-%{version}.tar.bz2
Source100:  picoplayer.yaml
Requires:   sailfishsilica-qt5 >= 0.10.9
Requires:   mpris-qt5-qml-plugin
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Gui)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5OpenGL)
BuildRequires:  pkgconfig(Qt5OpenGLExtensions)
BuildRequires:  pkgconfig(audioresource-qt)
BuildRequires:  pkgconfig(dbus-1)
BuildRequires:  pkgconfig(dbus-glib-1)
BuildRequires:  pkgconfig(gstreamer-webrtc-1.0)
BuildRequires:  pkgconfig(gstreamer-sdp-1.0)
BuildRequires:  pkgconfig(gstreamer-1.0)
BuildRequires:  pkgconfig(glib-2.0)
BuildRequires:  pkgconfig(nemo-gstreamer-interfaces-1.0)
BuildRequires:  dbus-glib-devel
BuildRequires:  nemo-qml-plugin-notifications-qt5-devel
BuildRequires:  desktop-file-utils
BuildRequires:  ninja

%description
Short description of my Sailfish OS Application


%prep
%setup -q -n %{name}-%{version}

%build
%cmake .
make %{?_smp_mflags}

%install
rm -rf %{buildroot}
%make_install

desktop-file-install --delete-original       \
  --dir %{buildroot}%{_datadir}/applications             \
   %{buildroot}%{_datadir}/applications/*.desktop

%files
%defattr(-,root,root,-)
%{_bindir}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
