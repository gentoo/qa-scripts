<?xml version="1.0" encoding="utf-8"?>
<!--
	SPDX-License-Identifier: GPL-2.0-only
	Copyright 2026 Gentoo Authors
	Author: Brett A C Sheffield <bacs@librecast.net>
-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fo="http://www.w3.org/1999/XSL/Format">
	<xsl:output method="html"/>

	<xsl:param name="now" select="now"/>

	<xsl:template match="/">
		<html>
			<head>
				<title>Dormant Projects</title>
			</head>
			<body>
				<h1>Dormant Projects</h1>
				<p>The following projects do not have any members at present (last updated <xsl:value-of select="$now"/>):</p>
				<table>
					<tr>
						<th>Project</th>
						<th>Packages</th>
						<th>Bugs</th>
						<th>Description</th>
					</tr>
					<xsl:apply-templates select="projects/project[not(member)]"/>
				</table>
			</body>
		</html>
	</xsl:template>

	<xsl:template match="project">
		<tr>
			<td>
				<a>
					<xsl:attribute name="href">
						<xsl:value-of select="url"/>
					</xsl:attribute>
					<xsl:value-of select="name"/>
				</a>
			</td>
			<td>
				<a>
					<xsl:attribute name="href">https://packages.gentoo.org/maintainer/<xsl:value-of select="email"/></xsl:attribute>
					Packages
				</a>
			</td>
			<td>
				<a>
					<xsl:attribute name="href">https://packages.gentoo.org/maintainer/<xsl:value-of select="email"/>/bugs</xsl:attribute>
					Bugs
				</a>
			</td>
			<td>
				<xsl:value-of select="description"/>
			</td>
		</tr>
	</xsl:template>

</xsl:stylesheet>
