Name:		dracut-modules-olpc
Version:	0.1
Release:	1%{?dist}
Summary:	OLPC modules for dracut initramfs

Group:		System Environment/Base
License:	GPLv2
URL:		http://dev.laptop.org/git/users/dsd/dracut-modules-olpc
Source0:	%{name}-%{version}.tar.bz2
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildRequires:	dracut
Requires:		dracut

%description
OLPC-specific modules for dracut

%prep
%setup -q


%build


%install
rm -rf $RPM_BUILD_ROOT
%{__install} -d $RPM_BUILD_ROOT/usr/share/dracut/modules.d/20olpc-bootanim
%{__install} -m 755 -t $RPM_BUILD_ROOT/usr/share/dracut/modules.d/20olpc-bootanim 20olpc-bootanim/install 20olpc-bootanim/check 20olpc-bootanim/startanim.sh


%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%doc
%{_prefix}/share/dracut/modules.d/20olpc-bootanim


%changelog
* Tue Jun 23 2009 Daniel Drake <dsd@laptop.org> - 0.1-1
- Initial release, includes olpc-bootanim module

